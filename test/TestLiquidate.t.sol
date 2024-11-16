// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestLiquidate is TestSetup {
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;

    // A user liquidates a borrower that has enough collateral to cover for his debt, the transaction reverts.
    function testShouldNotBePossibleToLiquidateUserAboveWater() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, address(evoq), (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        // Liquidate
        uint256 toRepay = amount / 2;
        User liquidator = borrower3;
        liquidator.approve(dai, address(evoq), toRepay);

        hevm.expectRevert(abi.encodeWithSignature("UnauthorisedLiquidate()"));
        liquidator.liquidate(vDai, vUsdc, address(borrower1), toRepay);
    }

    function testShouldNotLiquidateZero() public {
        hevm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        borrower2.liquidate(vDai, vUsdc, address(borrower1), 0);
    }

    function testLiquidateWhenMarketDeprecated() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = (3 * amount);

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        borrower1.borrow(vDai, amount);

        evoq.setIsBorrowPaused(vDai, true);
        evoq.setIsDeprecated(vDai, true);

        moveOneBlockForwardBorrowRepay();

        (, uint256 supplyOnPoolBefore) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

        // Liquidate
        uint256 toRepay = amount; // Full liquidation.
        User liquidator = borrower3;
        liquidator.approve(dai, address(evoq), toRepay);
        liquidator.liquidate(vDai, vUsdc, address(borrower1), toRepay);

        (, uint256 supplyOnPoolAfter) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));
        (, uint256 borrowOnPoolAfter) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        uint256 collateralPrice = oracle.getUnderlyingPrice(vUsdc);
        uint256 borrowedPrice = oracle.getUnderlyingPrice(vDai);

        uint256 amountToSeize =
            toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(borrowedPrice).div(collateralPrice);

        uint256 expectedSupplyOnPoolAfter = supplyOnPoolBefore - amountToSeize.div(IVToken(vUsdc).exchangeRateCurrent());

        assertApproxEqAbs(supplyOnPoolAfter, expectedSupplyOnPoolAfter, 2);
        assertApproxEqAbs(borrowOnPoolAfter, 0, 1e15);
    }

    // A user liquidates a borrower that has not enough collateral to cover for his debt.
    function testShouldLiquidateUser() public {
        uint256 collateral = 100_000 ether;

        borrower1.approve(usdc, address(evoq), (collateral));
        borrower1.supply(vUsdc, (collateral));

        (, uint256 amount) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);
        borrower1.borrow(vDai, amount);

        (, uint256 collateralOnPool) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

        moveOneBlockForwardBorrowRepay();

        // Change Oracle.
        SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
        customOracle.setDirectPrice(usdc, (oracle.getUnderlyingPrice(vUsdc) * 98) / 100);

        // Liquidate.
        uint256 toRepay = amount / 2;
        User liquidator = borrower3;
        liquidator.approve(dai, address(evoq), toRepay);
        liquidator.liquidate(vDai, vUsdc, address(borrower1), toRepay);

        // Check borrower1 borrow balance.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        uint256 expectedBorrowBalanceOnPool = toRepay.div(IVToken(vDai).borrowIndex());
        testEqualityLarge(onPoolBorrower, expectedBorrowBalanceOnPool, "borrower borrow on pool");
        assertEq(inP2PBorrower, 0, "borrower borrow in peer-to-peer");

        // Check borrower1 supply balance.
        (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

        uint256 collateralPrice = customOracle.getUnderlyingPrice(vUsdc);
        uint256 borrowedPrice = customOracle.getUnderlyingPrice(vDai);

        uint256 amountToSeize =
            toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(borrowedPrice).div(collateralPrice);

        uint256 expectedOnPool = collateralOnPool - amountToSeize.div(IVToken(vUsdc).exchangeRateCurrent());

        testEquality(onPoolBorrower, expectedOnPool, "borrower supply on pool");
        assertEq(inP2PBorrower, 0, "borrower supply in peer-to-peer");
    }

    function testShouldLiquidateWhileInP2PAndPool() public {
        uint256 collateral = 10_000 ether;

        supplier1.approve(usdc, (collateral) / 2);
        supplier1.supply(vUsdc, (collateral) / 2);

        borrower1.approve(dai, collateral);
        borrower1.supply(vDai, collateral);

        (, uint256 borrowerDebt) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdc);
        (, uint256 supplierDebt) = lens.getUserMaxCapacitiesForAsset(address(supplier1), vDai);

        borrowerDebt = borrowerDebt - 1 ether; // fix rounding error

        supplier1.borrow(vDai, supplierDebt);
        borrower1.borrow(vUsdc, borrowerDebt);

        (uint256 inP2PUsdc, uint256 onPoolUsdc) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        (uint256 inP2PDai, uint256 onPoolDai) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        // Change Oracle.
        SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
        customOracle.setDirectPrice(dai, (oracle.getUnderlyingPrice(vDai) * 94) / 100);

        moveOneBlockForwardBorrowRepay();

        // Liquidate.
        uint256 toRepay = (borrowerDebt / 2) - 1; // -1 because of rounding error related to venus's approximation
        User liquidator = borrower3;
        liquidator.approve(usdc, toRepay);
        liquidator.liquidate(vUsdc, vDai, address(borrower1), toRepay);

        // Check borrower1 borrow balance.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = onPoolUsdc.mul(IVToken(vUsdc).borrowIndex())
            + inP2PUsdc.mul(evoq.p2pBorrowIndex(vUsdc)) - (borrowerDebt / 2);

        assertEq(onPoolBorrower, 0, "borrower borrow on pool");
        assertApproxEqAbs(
            inP2PBorrower.mul(evoq.p2pBorrowIndex(vUsdc)),
            expectedBorrowBalanceInP2P,
            1e9,
            "borrower borrow in peer-to-peer"
        );

        // Check borrower1 supply balance.
        (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        uint256 amountToSeize = toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(
            customOracle.getUnderlyingPrice(vUsdc)
        ).div(customOracle.getUnderlyingPrice(vDai));

        testEquality(
            onPoolBorrower,
            onPoolDai - amountToSeize.div(IVToken(vDai).exchangeRateCurrent()),
            "borrower supply on pool"
        );
        testEquality(inP2PBorrower, inP2PDai, "borrower supply in peer-to-peer");
    }

    function testShouldPartiallyLiquidateWhileInP2PAndPool() public {
        uint256 collateral = 10_000 ether;

        supplier1.approve(usdc, (collateral) / 2);
        supplier1.supply(vUsdc, (collateral) / 2);

        borrower1.approve(dai, collateral);
        borrower1.supply(vDai, collateral);

        (, uint256 borrowerDebt) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdc);
        (, uint256 supplierDebt) = lens.getUserMaxCapacitiesForAsset(address(supplier1), vDai);

        borrowerDebt = borrowerDebt - 1 ether; // fix rounding error

        supplier1.borrow(vDai, supplierDebt);
        borrower1.borrow(vUsdc, borrowerDebt);

        (uint256 inP2PUsdc, uint256 onPoolUsdc) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        (uint256 inP2PDai, uint256 onPoolDai) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        // Change Oracle.
        SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
        customOracle.setDirectPrice(dai, (oracle.getUnderlyingPrice(vDai) * 94) / 100);

        moveOneBlockForwardBorrowRepay();

        // Liquidate.
        uint256 toRepay = (borrowerDebt / 4);
        User liquidator = borrower3;
        liquidator.approve(usdc, toRepay);
        liquidator.liquidate(vUsdc, vDai, address(borrower1), toRepay);

        // Check borrower1 borrow balance.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        uint256 expectedBorrowBalanceOnPool = onPoolUsdc.mul(IVToken(vUsdc).borrowIndex()) - toRepay;

        testEqualityLarge(
            onPoolBorrower.mul(IVToken(vUsdc).borrowIndex()), expectedBorrowBalanceOnPool, "borrower borrow on pool"
        );
        testEquality(inP2PBorrower, inP2PUsdc, "borrower borrow in peer-to-peer");

        // Check borrower1 supply balance.
        (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        uint256 amountToSeize = toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(
            customOracle.getUnderlyingPrice(vUsdc)
        ).div(customOracle.getUnderlyingPrice(vDai));

        testEquality(
            onPoolBorrower,
            onPoolDai - amountToSeize.div(IVToken(vDai).exchangeRateCurrent()),
            "borrower supply on pool"
        );
        testEquality(inP2PBorrower, inP2PDai, "borrower supply in peer-to-peer");
    }

    function testFailLiquidateZero() public {
        evoq.liquidate(vDai, vDai, vDai, 0);
    }

    struct StackP2PVars {
        uint256 daiP2PSupplyIndexBefore;
        uint256 daiP2PBorrowIndexBefore;
        uint256 usdcP2PSupplyIndexBefore;
        uint256 usdcP2PBorrowIndexBefore;
        uint256 maticP2PSupplyIndexBefore;
        uint256 maticP2PBorrowIndexBefore;
        uint256 usdtP2PSupplyIndexBefore;
        uint256 usdtP2PBorrowIndexBefore;
    }

    struct StackPoolVars {
        uint256 daiPoolSupplyIndexBefore;
        uint256 daiPoolBorrowIndexBefore;
        uint256 usdcPoolSupplyIndexBefore;
        uint256 usdcPoolBorrowIndexBefore;
        uint256 maticPoolSupplyIndexBefore;
        uint256 maticPoolBorrowIndexBefore;
        uint256 usdtPoolSupplyIndexBefore;
        uint256 usdtPoolBorrowIndexBefore;
    }

    function testLiquidateUpdateIndexesSameAsVenus() public {
        uint256 collateral = 1 ether;
        uint256 borrow = collateral / 2;
        uint256 formerPriceDai;
        uint256 formerPriceUsdc;
        createMarket(vMatic);

        {
            supplier1.approve(dai, type(uint256).max);
            supplier1.approve(usdc, type(uint256).max);
            supplier1.approve(usdt, type(uint256).max);

            supplier1.supply(vDai, collateral);
            supplier1.supply(vUsdc, collateral);

            supplier1.borrow(vMatic, borrow);
            supplier1.borrow(vUsdt, borrow);

            supplier2.approve(wBnb, type(uint256).max);
            supplier2.supply(vBnb, collateral);

            StackP2PVars memory vars;

            vars.daiP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vDai);
            vars.daiP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vDai);
            vars.usdcP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vUsdc);
            vars.usdcP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vUsdc);
            vars.maticP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vMatic);
            vars.maticP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vMatic);
            vars.usdtP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vUsdt);
            vars.usdtP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vUsdt);

            hevm.roll(block.number + 1);

            // Change Oracle.
            SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
            formerPriceDai = oracle.getUnderlyingPrice(vDai);
            formerPriceUsdc = oracle.getUnderlyingPrice(vUsdc);
            customOracle.setDirectPrice(dai, (formerPriceDai * 10) / 100);
            customOracle.setDirectPrice(usdc, (formerPriceUsdc * 10) / 100);

            // Liquidate.
            uint256 toRepay = ((borrow) * 1) / 100;
            User liquidator = borrower3;
            liquidator.approve(usdt, toRepay);
            liquidator.liquidate(vUsdt, vDai, address(supplier1), toRepay);

            // Reset former price on oracle.
            customOracle.setDirectPrice(dai, formerPriceDai);
            customOracle.setDirectPrice(usdc, formerPriceUsdc);

            uint256 daiP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vDai);
            uint256 daiP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vDai);
            uint256 usdcP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vUsdc);
            uint256 usdcP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vUsdc);
            uint256 maticP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vMatic);
            uint256 maticP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vMatic);
            uint256 usdtP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vUsdt);
            uint256 usdtP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vUsdt);

            assertGt(daiP2PBorrowIndexAfter, vars.daiP2PSupplyIndexBefore);
            assertGt(daiP2PSupplyIndexAfter, vars.daiP2PBorrowIndexBefore);
            assertEq(usdcP2PSupplyIndexAfter, vars.usdcP2PSupplyIndexBefore);
            assertEq(usdcP2PBorrowIndexAfter, vars.usdcP2PBorrowIndexBefore);
            assertEq(maticP2PSupplyIndexAfter, vars.maticP2PSupplyIndexBefore);
            assertEq(maticP2PBorrowIndexAfter, vars.maticP2PBorrowIndexBefore);
            assertGt(usdtP2PSupplyIndexAfter, vars.usdtP2PSupplyIndexBefore);
            assertGt(usdtP2PBorrowIndexAfter, vars.usdtP2PBorrowIndexBefore);
        }

        {
            supplier1.venusSupply(vDai, collateral);
            supplier1.venusSupply(vUsdc, (collateral));

            supplier1.venusBorrow(vMatic, borrow);
            supplier1.venusBorrow(vUsdt, (borrow));

            StackPoolVars memory vars;

            vars.daiPoolSupplyIndexBefore = IVToken(vDai).exchangeRateStored();
            vars.daiPoolBorrowIndexBefore = IVToken(vDai).borrowIndex();
            vars.usdcPoolSupplyIndexBefore = IVToken(vUsdc).exchangeRateStored();
            vars.usdcPoolBorrowIndexBefore = IVToken(vUsdc).borrowIndex();
            vars.maticPoolSupplyIndexBefore = IVToken(vMatic).exchangeRateStored();
            vars.maticPoolBorrowIndexBefore = IVToken(vMatic).borrowIndex();
            vars.usdtPoolSupplyIndexBefore = IVToken(vUsdt).exchangeRateStored();
            vars.usdtPoolBorrowIndexBefore = IVToken(vUsdt).borrowIndex();

            hevm.roll(block.number + 1);

            // Change Oracle.
            SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
            customOracle.setDirectPrice(dai, (formerPriceDai * 10) / 100);
            customOracle.setDirectPrice(usdc, (formerPriceUsdc * 10) / 100);

            // Liquidate.
            uint256 toRepay = ((borrow) * 1) / 100;
            hevm.prank(address(borrower3));
            ERC20(usdt).safeApprove(vUsdt, type(uint256).max);
            hevm.prank(address(borrower3));
            IVToken(vUsdt).liquidateBorrow(address(supplier1), toRepay, vDai);

            // Reset former price on oracle.
            customOracle.setDirectPrice(dai, formerPriceDai);
            customOracle.setDirectPrice(usdc, formerPriceUsdc);

            uint256 daiPoolSupplyIndexAfter = IVToken(vDai).exchangeRateStored();
            uint256 daiPoolBorrowIndexAfter = IVToken(vDai).borrowIndex();
            uint256 usdcPoolSupplyIndexAfter = IVToken(vUsdc).exchangeRateStored();
            uint256 usdcPoolBorrowIndexAfter = IVToken(vUsdc).borrowIndex();
            uint256 maticPoolSupplyIndexAfter = IVToken(vMatic).exchangeRateStored();
            uint256 maticPoolBorrowIndexAfter = IVToken(vMatic).borrowIndex();
            uint256 usdtPoolSupplyIndexAfter = IVToken(vUsdt).exchangeRateStored();
            uint256 usdtPoolBorrowIndexAfter = IVToken(vUsdt).borrowIndex();

            assertGt(daiPoolSupplyIndexAfter, vars.daiPoolSupplyIndexBefore);
            assertGt(daiPoolBorrowIndexAfter, vars.daiPoolBorrowIndexBefore);
            assertEq(usdcPoolSupplyIndexAfter, vars.usdcPoolSupplyIndexBefore);
            assertEq(usdcPoolBorrowIndexAfter, vars.usdcPoolBorrowIndexBefore);
            assertEq(maticPoolSupplyIndexAfter, vars.maticPoolSupplyIndexBefore);
            assertEq(maticPoolBorrowIndexAfter, vars.maticPoolBorrowIndexBefore);
            assertGt(usdtPoolSupplyIndexAfter, vars.usdtPoolSupplyIndexBefore);
            assertGt(usdtPoolBorrowIndexAfter, vars.usdtPoolBorrowIndexBefore);
        }
    }

    function testCannotLiquidateMoreThanCloseFactor() public {
        uint256 amount = 10_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, oracle.getUnderlyingPrice(vDai));

        borrower1.approve(usdc, type(uint256).max);
        borrower1.supply(vUsdc, (amount * 2));
        borrower1.borrow(vDai, amount);

        oracle.setUnderlyingPrice(vUsdc, oracle.getUnderlyingPrice(vUsdc) / 2);
        vm.roll(block.number + 1);

        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        hevm.expectRevert(abi.encodeWithSignature("AmountAboveWhatAllowedToRepay()"));
        evoq.liquidate(vDai, vUsdc, address(borrower1), (amount * 3) / 4);
    }

    function testCannotBorrowLiquidateInSameBlock() public {
        uint256 amount = 10_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, oracle.getUnderlyingPrice(vDai));

        borrower1.approve(usdc, type(uint256).max);
        borrower1.supply(vUsdc, (amount * 2));
        borrower1.borrow(vDai, amount);

        oracle.setUnderlyingPrice(vUsdc, oracle.getUnderlyingPrice(vUsdc) / 2);

        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        hevm.expectRevert(abi.encodeWithSignature("SameBlockBorrowRepay()"));
        evoq.liquidate(vDai, vUsdc, address(borrower1), amount / 3);
    }

    function testShouldCollectRightLiquidationFee() public {}
}
