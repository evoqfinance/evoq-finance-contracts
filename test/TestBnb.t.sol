// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestEth is TestSetup {
    using CompoundMath for uint256;

    function testSupplyEthOnPool() public {
        uint256 toSupply = 100 ether;

        uint256 balanceBefore = supplier1.balanceOf(wBnb);
        supplier1.approve(wBnb, address(evoq), toSupply);
        supplier1.supply(vBnb, toSupply);
        uint256 balanceAfter = supplier1.balanceOf(wBnb);

        uint256 poolSupplyIndex = IVToken(vBnb).exchangeRateCurrent();
        uint256 expectedOnPool = toSupply.div(poolSupplyIndex);

        testEquality(ERC20(vBnb).balanceOf(address(evoq)), expectedOnPool, "balance of vToken");

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vBnb, address(supplier1));

        assertEq(inP2P, 0);
        testEquality(onPool, expectedOnPool);
        testEquality(balanceAfter, balanceBefore - toSupply);
    }

    function testSupplyEthInP2P() public {
        uint256 collateral = (100_000 ether);
        uint256 toSupply = 1 ether;
        uint256 toBorrow = 1 ether;

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        borrower1.borrow(vBnb, toBorrow);

        uint256 balanceBefore = supplier1.balanceOf(wBnb);
        supplier1.approve(wBnb, address(evoq), toSupply);
        supplier1.supply(vBnb, toSupply);
        uint256 balanceAfter = supplier1.balanceOf(wBnb);

        uint256 p2pSupplyIndex = lens.getCurrentP2PSupplyIndex(vBnb);

        uint256 expectedInP2P = toSupply.div(p2pSupplyIndex);

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vBnb, address(supplier1));

        assertEq(onPool, 0);
        testEquality(inP2P, expectedInP2P);
        testEquality(balanceAfter, balanceBefore - toSupply);
    }

    function testBorrowEthOnPool() public {
        uint256 collateral = (100_000 ether);
        uint256 toSupply = 1 ether;
        uint256 toBorrow = 1 ether;

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        uint256 balanceBefore = borrower1.balanceOf(wBnb);
        borrower1.borrow(vBnb, toBorrow);
        uint256 balanceAfter = borrower1.balanceOf(wBnb);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vBnb, address(borrower1));

        uint256 expectedOnPool = toSupply.div(IVToken(vBnb).borrowIndex());

        testEquality(onPool, expectedOnPool);
        assertEq(inP2P, 0);
        testEquality(balanceAfter, balanceBefore + toBorrow);
    }

    function testBorrowEthInP2P() public {
        uint256 collateral = (100_000 ether);
        uint256 toSupply = 1 ether;

        supplier1.approve(wBnb, address(evoq), toSupply);
        supplier1.supply(vBnb, toSupply);

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        uint256 vBnbIndex = IVToken(vBnb).exchangeRateCurrent();
        uint256 balanceBefore = borrower1.balanceOf(wBnb);
        (, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vBnb, address(supplier1));
        uint256 toBorrow = supplyOnPool.mul(vBnbIndex);
        borrower1.borrow(vBnb, toBorrow);
        uint256 balanceAfter = borrower1.balanceOf(wBnb);

        uint256 expectedInP2P = toSupply.div(evoq.p2pBorrowIndex(vBnb));

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vBnb, address(borrower1));

        assertEq(onPool, 0);
        testEquality(inP2P, expectedInP2P);
        assertApproxEqAbs(balanceAfter, balanceBefore + toBorrow, 1e9);
    }

    function testWithdrawEthOnPool() public {
        uint256 toSupply = 1 ether;

        uint256 balanceBefore = supplier1.balanceOf(wBnb);
        supplier1.approve(wBnb, address(evoq), toSupply);
        supplier1.supply(vBnb, toSupply);

        supplier1.withdraw(vBnb, toSupply);
        uint256 balanceAfter = supplier1.balanceOf(wBnb);

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vBnb, address(borrower1));

        assertEq(onPool, 0);
        assertEq(inP2P, 0);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testWithdrawEthInP2P() public {
        uint256 collateral = (100_000 ether);
        uint256 toSupply = 1 ether;
        uint256 toBorrow = 1 ether;

        uint256 balanceBefore = supplier1.balanceOf(wBnb);
        supplier1.approve(wBnb, address(evoq), toSupply);
        supplier1.supply(vBnb, toSupply);

        borrower1.approve(usdc, collateral);
        borrower1.supply(vUsdc, collateral);
        borrower1.borrow(vBnb, toBorrow);

        supplier1.withdraw(vBnb, toSupply);
        uint256 balanceAfter = supplier1.balanceOf(wBnb);

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vBnb, address(borrower1));

        assertEq(onPool, 0);
        assertEq(inP2P, 0);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9);
    }

    function testRepayEthOnPool() public {
        uint256 collateral = (100_000 ether);
        uint256 toBorrow = 1 ether;

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        uint256 balanceBefore = borrower1.balanceOf(wBnb);
        borrower1.borrow(vBnb, toBorrow);

        moveOneBlockForwardBorrowRepay();

        borrower1.approve(wBnb, address(evoq), toBorrow);
        borrower1.repay(vBnb, toBorrow);
        uint256 balanceAfter = borrower1.balanceOf(wBnb);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vBnb, address(borrower1));

        testEqualityLarge(onPool, 0);
        testEquality(inP2P, 0);
        testEquality(balanceAfter, balanceBefore);
    }

    function testRepayEthInP2P() public {
        uint256 collateral = (100_000 ether);
        uint256 toSupply = 1 ether;
        uint256 toBorrow = 1 ether;
        uint256 toRepay = 1 ether;

        borrower1.approve(wBnb, address(evoq), toSupply);
        borrower1.supply(vBnb, toSupply);

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);
        uint256 balanceBefore = borrower1.balanceOf(wBnb);
        borrower1.borrow(vBnb, toBorrow);

        moveOneBlockForwardBorrowRepay();

        borrower1.approve(wBnb, address(evoq), toRepay);
        borrower1.repay(vBnb, toRepay);
        uint256 balanceAfter = borrower1.balanceOf(wBnb);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vBnb, address(borrower1));

        assertApproxEqAbs(onPool, 0, 2e2);
        assertApproxEqAbs(inP2P, 0, 2e2);
        assertApproxEqAbs(balanceAfter, balanceBefore, 1e9, "balance");
    }

    function testShouldLiquidateUserWithEthBorrowed() public {
        uint256 collateral = (100_000 ether);

        // supplier1 supplies surplus of USDC to put Evoq clearly above water.
        supplier1.approve(usdc, address(evoq), collateral);
        supplier1.supply(vUsdc, collateral);

        borrower1.approve(usdc, address(evoq), collateral);
        borrower1.supply(vUsdc, collateral);

        (, uint256 amount) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vBnb);
        borrower1.borrow(vBnb, amount);

        (, uint256 collateralOnPool) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

        moveOneBlockForwardBorrowRepay();

        // Change Oracle.
        SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
        customOracle.setDirectPrice(usdc, (oracle.getUnderlyingPrice(vUsdc) * 95) / 100);

        // Liquidate.
        uint256 toRepay = (amount * 1) / 3;
        User liquidator = borrower3;
        uint256 balanceBefore = liquidator.balanceOf(wBnb);

        liquidator.approve(wBnb, address(evoq), toRepay);
        liquidator.liquidate(vBnb, vUsdc, address(borrower1), toRepay);
        uint256 balanceAfter = liquidator.balanceOf(wBnb);

        // Check borrower1 borrow balance.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vBnb, address(borrower1));
        uint256 expectedBorrowBalanceOnPool = (amount - toRepay).div(IVToken(vBnb).borrowIndex());
        testEqualityLarge(onPoolBorrower, expectedBorrowBalanceOnPool, "borrower borrow on pool");
        assertEq(inP2PBorrower, 0, "borrower borrow in peer-to-peer");

        // Check borrower1 supply balance.
        (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

        uint256 collateralPrice = customOracle.getUnderlyingPrice(vUsdc);
        uint256 borrowedPrice = customOracle.getUnderlyingPrice(vBnb);

        uint256 amountToSeize =
            toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(borrowedPrice).div(collateralPrice);

        uint256 expectedOnPool = collateralOnPool - amountToSeize.div(IVToken(vUsdc).exchangeRateCurrent());

        testEquality(onPoolBorrower, expectedOnPool, "borrower supply on pool");
        testEquality(balanceAfter, balanceBefore - toRepay, "amount seized");
        assertEq(inP2PBorrower, 0, "borrower supply in peer-to-peer");
    }

    function testShouldLiquidateUserWithEthAsCollateral() public {
        uint256 collateral = 1 ether;
        uint256 toSupplyMore = (100_000 ether);

        // supplier1 supplies surplus of USDC to put Evoq clearly above water.
        supplier1.approve(usdc, address(evoq), toSupplyMore);
        supplier1.supply(vUsdc, toSupplyMore);

        borrower1.approve(wBnb, address(evoq), collateral);
        borrower1.supply(vBnb, collateral);

        (, uint256 amount) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdt);
        borrower1.borrow(vUsdt, amount);

        (, uint256 collateralOnPool) = evoq.supplyBalanceInOf(vBnb, address(borrower1));

        moveOneBlockForwardBorrowRepay();

        // Change Oracle.
        SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
        customOracle.setDirectPrice(usdt, (oracle.getUnderlyingPrice(vUsdt) * 105) / 100);

        // Liquidate.
        uint256 toRepay = (amount * 1) / 3;
        User liquidator = borrower3;
        uint256 balanceBefore = liquidator.balanceOf(wBnb);
        liquidator.approve(usdt, address(evoq), toRepay);
        liquidator.liquidate(vUsdt, vBnb, address(borrower1), toRepay);
        uint256 balanceAfter = liquidator.balanceOf(wBnb);

        // Check borrower1 borrow balance.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));
        uint256 expectedBorrowBalanceOnPool = (amount - toRepay).div(IVToken(vUsdt).borrowIndex());
        testEqualityLarge(onPoolBorrower, expectedBorrowBalanceOnPool, "borrower borrow on pool");
        assertEq(inP2PBorrower, 0, "borrower borrow in peer-to-peer");

        // Check borrower1 supply balance.
        (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vBnb, address(borrower1));

        uint256 collateralPrice = customOracle.getUnderlyingPrice(vBnb);
        uint256 borrowedPrice = customOracle.getUnderlyingPrice(vUsdt);

        uint256 amountToSeize =
            toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(borrowedPrice).div(collateralPrice);

        uint256 expectedOnPool = collateralOnPool - amountToSeize.div(IVToken(vBnb).exchangeRateCurrent());

        testEquality(onPoolBorrower, expectedOnPool, "borrower supply on pool");
        testEquality(balanceAfter, balanceBefore + amountToSeize, "amount seized");
        assertEq(inP2PBorrower, 0, "borrower supply in peer-to-peer");
    }

    function testShouldGetEthMarketConfiguration() public view {
        (address underlying,,,,,) = lens.getMarketConfiguration(vBnb);

        assertEq(underlying, wBnb);
    }
}
