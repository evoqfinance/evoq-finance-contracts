// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestLens is TestSetup {
    using CompoundMath for uint256;

    struct UserBalanceStates {
        uint256 collateralUsd;
        uint256 debtUsd;
        uint256 maxDebtUsd;
        uint256 liquidationUsd;
    }

    struct UserBalance {
        uint256 onPool;
        uint256 inP2P;
        uint256 totalBalance;
    }

    function testUserSummary() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, amount / 2);

        IDataLens.UserSummary memory data = dataLens.getUserSummary(address(borrower1));
        assertGe(data.totalSupplyRate, 0);
        assertGe(data.totalBorrowRate, 0);
    }

    function testUserMarketsData() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, amount / 2);

        IDataLens.UserMarketData[] memory userMarketsData = dataLens.getUserMarketsData(address(borrower1));
        for (uint256 i; i < userMarketsData.length; i++) {
            IDataLens.UserMarketData memory data = userMarketsData[i];
            if (data.underlying == dai) {
                assertEq(data.poolToken, vDai, "Wrong pool token");
                assertApproxEqAbs(data.supplyTotal, amount, 1e9, "userMarketsData, supplyTotal");
            }

            if (data.underlying == usdc) {
                assertEq(data.poolToken, vUsdc, "Wrong pool token");
                testEquality(data.borrowTotal, amount / 2, "userMarketsData, borrowTotal");
            }
        }
    }

    function testMarketSummary() public {
        supplier1.approve(dai, 10_000 ether);
        supplier1.supply(vDai, 10_000 ether);

        borrower1.approve(usdc, 10_000 ether);
        borrower1.supply(vUsdc, 10_000 ether);
        borrower1.borrow(vDai, 5_000 ether);

        IDataLens.MarketSummary memory data = dataLens.getMarketSummary();
        assertEq(data.matchingEfficiency, 1 ether, "matchingEfficiency should be 100%");
    }

    function testMarketsData() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, amount / 2);

        IDataLens.MarketsData[] memory marketsData = dataLens.getMarketsData();
        for (uint256 i; i < marketsData.length; i++) {
            IDataLens.MarketsData memory data = marketsData[i];
            if (data.underlying == dai) {
                assertEq(data.poolToken, vDai, "Wrong pool token");
                assertApproxEqAbs(data.supplyTotal, amount, 1e9, "marketsData, supplyTotal");
            }

            if (data.underlying == usdc) {
                assertEq(data.poolToken, vUsdc, "Wrong pool token");
                testEquality(data.borrowTotal, amount / 2, "marketsData, borrowTotal");
            }
        }
    }

    function testUserLiquidityDataForAssetWithNothing() public {
        Types.AssetLiquidityData memory assetData =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        (, uint256 collateralFactor,) = comptroller.markets(vDai);
        uint256 underlyingPrice = oracle.getUnderlyingPrice(vDai);

        assertEq(assetData.collateralFactor, collateralFactor);
        assertEq(assetData.underlyingPrice, underlyingPrice);
        assertEq(assetData.collateralUsd, 0);
        assertEq(assetData.maxDebtUsd, 0);
        assertEq(assetData.debtUsd, 0);
    }

    function testUserLiquidityDataForAssetWithSupply() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        Types.AssetLiquidityData memory assetData =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        (, uint256 collateralFactor,) = comptroller.markets(vDai);
        uint256 underlyingPrice = oracle.getUnderlyingPrice(vDai);

        uint256 collateralValue = getBalanceOnVenus(amount, IVToken(vDai).exchangeRateStored()).mul(underlyingPrice);
        uint256 maxDebtValue = collateralValue.mul(collateralFactor);

        assertEq(assetData.collateralFactor, collateralFactor, "collateralFactor");
        assertEq(assetData.underlyingPrice, underlyingPrice, "underlyingPrice");
        assertEq(assetData.collateralUsd, collateralValue, "collateralValue");
        assertEq(assetData.maxDebtUsd, maxDebtValue, "maxDebtValue");
        assertEq(assetData.debtUsd, 0, "debtValue");
    }

    struct Indexes {
        uint256 index1;
        uint256 index2;
    }

    function testUserLiquidityDataForAssetWithSupplyAndBorrow() public {
        Indexes memory indexes;
        uint256 amount = 10_000 ether;
        uint256 toBorrow = amount / 2;

        borrower1.approve(dai, type(uint256).max);
        indexes.index1 = IVToken(vDai).exchangeRateCurrent();
        borrower1.supply(vDai, amount);
        borrower1.borrow(vDai, toBorrow);

        indexes.index2 = IVToken(vDai).exchangeRateCurrent();

        Types.AssetLiquidityData memory assetData =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        (, uint256 collateralFactor,) = comptroller.markets(vDai);
        uint256 underlyingPrice = oracle.getUnderlyingPrice(vDai);

        uint256 total;

        // To update p2p indexes on Evoq (they can change inside of a block because the poolSupplyIndex can change due to rounding errors).
        borrower1.supply(vDai, 1);
        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);
        {
            uint256 onPool = amount.div(indexes.index1);
            uint256 matchedInP2P = toBorrow.div(evoq.p2pSupplyIndex(vDai));
            uint256 onPoolAfter = onPool - toBorrow.div(indexes.index2);
            total = onPoolAfter.mul(indexes.index2) + matchedInP2P.mul(evoq.p2pSupplyIndex(vDai));
        }

        uint256 collateralValue = total.mul(underlyingPrice);
        uint256 maxDebtValue = collateralValue.mul(collateralFactor);
        // Divide and multiply to take into account rounding errors.
        uint256 debtValue = toBorrow.div(p2pBorrowIndex).mul(p2pBorrowIndex).mul(underlyingPrice);

        assertEq(assetData.underlyingPrice, underlyingPrice, "underlyingPrice");
        assertEq(assetData.collateralUsd, collateralValue, "collateralValue");
        assertEq(assetData.maxDebtUsd, maxDebtValue, "maxDebtValue");
        assertEq(assetData.debtUsd, debtValue, "debtValue");
    }

    function testUserLiquidityDataForAssetWithSupplyAndBorrowWithMultipleAssets() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = (amount / 2);

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, toBorrow);

        Types.AssetLiquidityData memory assetDataCDai =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        Types.AssetLiquidityData memory assetDataCUsdc =
            lens.getUserLiquidityDataForAsset(address(borrower1), vUsdc, true, oracle);

        // Avoid stack too deep error.
        Types.AssetLiquidityData memory expectedDataCUsdc;
        expectedDataCUsdc.underlyingPrice = oracle.getUnderlyingPrice(vUsdc);

        expectedDataCUsdc.debtUsd =
            getBalanceOnVenus(toBorrow, IVToken(vUsdc).borrowIndex()).mul(expectedDataCUsdc.underlyingPrice);

        assertEq(assetDataCUsdc.underlyingPrice, expectedDataCUsdc.underlyingPrice, "underlyingPriceUsdc");
        assertEq(assetDataCUsdc.collateralUsd, 0, "collateralValue");
        assertEq(assetDataCUsdc.maxDebtUsd, 0, "maxDebtValue");
        assertEq(assetDataCUsdc.debtUsd, expectedDataCUsdc.debtUsd, "debtValueUsdc");

        // Avoid stack too deep error.
        Types.AssetLiquidityData memory expectedDataCDai;

        (, expectedDataCDai.collateralFactor,) = comptroller.markets(vDai);

        expectedDataCDai.underlyingPrice = oracle.getUnderlyingPrice(vDai);
        expectedDataCDai.collateralUsd =
            getBalanceOnVenus(amount, IVToken(vDai).exchangeRateStored()).mul(expectedDataCDai.underlyingPrice);
        expectedDataCDai.maxDebtUsd = expectedDataCDai.collateralUsd.mul(expectedDataCDai.collateralFactor);

        assertEq(assetDataCDai.collateralFactor, expectedDataCDai.collateralFactor, "collateralFactor");
        assertEq(assetDataCDai.underlyingPrice, expectedDataCDai.underlyingPrice, "underlyingPriceDai");

        assertEq(assetDataCDai.collateralUsd, expectedDataCDai.collateralUsd, "collateralValueDai");
        assertEq(assetDataCDai.maxDebtUsd, expectedDataCDai.maxDebtUsd, "maxDebtValueDai");
        assertEq(assetDataCDai.debtUsd, 0, "debtValueDai");
    }

    function testMaxCapacitiesWithNothing() public {
        (uint256 withdrawable, uint256 borrowable) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        assertEq(withdrawable, 0);
        assertEq(borrowable, 0);
    }

    function testMaxCapacitiesWithSupply() public {
        uint256 amount = (10000 ether);

        borrower1.approve(usdc, amount);
        borrower1.supply(vUsdc, amount);

        Types.AssetLiquidityData memory assetDataCUsdc =
            lens.getUserLiquidityDataForAsset(address(borrower1), vUsdc, true, oracle);

        Types.AssetLiquidityData memory assetDataCDai =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        uint256 expectedBorrowableUsdc = assetDataCUsdc.maxDebtUsd.div(assetDataCUsdc.underlyingPrice);
        uint256 expectedBorrowableDai = assetDataCUsdc.maxDebtUsd.div(assetDataCDai.underlyingPrice);

        (uint256 withdrawable, uint256 borrowable) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdc);

        assertApproxEqAbs(
            withdrawable, getBalanceOnVenus(amount, IVToken(vUsdc).exchangeRateStored()), 3, "withdrawable USDC"
        );
        assertEq(borrowable, expectedBorrowableUsdc, "borrowable USDC");

        (withdrawable, borrowable) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        assertEq(withdrawable, 0, "withdrawable DAI");
        assertEq(borrowable, expectedBorrowableDai, "borrowable DAI");
    }

    function testMaxCapacitiesWithSupplyAndBorrow() public {
        uint256 amount = 100 ether;

        createMarket(vCake);

        borrower1.approve(cake, amount);
        borrower1.supply(vCake, amount);

        (uint256 withdrawableBatBefore, uint256 borrowableBatBefore) =
            lens.getUserMaxCapacitiesForAsset(address(borrower1), vCake);
        (uint256 withdrawableDaiBefore, uint256 borrowableDaiBefore) =
            lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        borrower1.borrow(vDai, borrowableDaiBefore / 2);

        (uint256 withdrawableBatAfter, uint256 borrowableBatAfter) =
            lens.getUserMaxCapacitiesForAsset(address(borrower1), vCake);
        (uint256 withdrawableDaiAfter, uint256 borrowableDaiAfter) =
            lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        (, uint256 cakeCollateralFactor,) = comptroller.markets(vCake);

        assertApproxEqAbs(withdrawableBatBefore, amount, 1e9, "cannot withdraw all CAKE");
        assertApproxEqAbs(borrowableBatBefore, amount.mul(cakeCollateralFactor), 2 * 1e9, "cannot borrow all CAKE");
        assertEq(withdrawableDaiBefore, 0, "can withdraw DAI not supplied");
        assertApproxEqAbs(
            borrowableDaiBefore,
            amount.mul(cakeCollateralFactor).mul(oracle.getUnderlyingPrice(vCake).div(oracle.getUnderlyingPrice(vDai))),
            2 * 1e9,
            "cannot borrow all DAI"
        );
        assertApproxEqAbs(borrowableBatAfter, borrowableBatBefore / 2, 2 * 10, "cannot borrow half CAKE");
        assertEq(withdrawableDaiAfter, 0, "unexpected withdrawable DAI");
        assertApproxEqAbs(borrowableDaiAfter, borrowableDaiBefore / 2, 10, "cannot borrow half DAI");

        vm.expectRevert(PositionsManager.UnauthorisedWithdraw.selector);
        borrower1.withdraw(vCake, withdrawableBatAfter + 1e8);
    }

    function testUserBalanceWithoutMatching() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = (amount / 2);

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, toBorrow);

        UserBalance memory userSupplyBalance;

        (userSupplyBalance.onPool, userSupplyBalance.inP2P, userSupplyBalance.totalBalance) =
            lens.getCurrentSupplyBalanceInOf(vDai, address(borrower1));

        (uint256 supplyBalanceInP2P, uint256 supplyBalanceOnPool) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        uint256 expectedSupplyBalanceInP2P = supplyBalanceInP2P.mul(evoq.p2pSupplyIndex(vDai));
        uint256 expectedSupplyBalanceOnPool = supplyBalanceOnPool.mul(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedTotalSupplyBalance = expectedSupplyBalanceInP2P + expectedSupplyBalanceOnPool;

        assertEq(userSupplyBalance.onPool, expectedSupplyBalanceOnPool, "On pool supply balance");
        assertEq(userSupplyBalance.inP2P, expectedSupplyBalanceInP2P, "P2P supply balance");
        assertEq(userSupplyBalance.totalBalance, expectedTotalSupplyBalance, "Total supply balance");

        UserBalance memory userBorrowBalance;

        (userBorrowBalance.onPool, userBorrowBalance.inP2P, userBorrowBalance.totalBalance) =
            lens.getCurrentBorrowBalanceInOf(vUsdc, address(borrower1));

        (uint256 borrowBalanceInP2P, uint256 borrowBalanceOnPool) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = borrowBalanceInP2P.mul(evoq.p2pBorrowIndex(vUsdc));
        uint256 expectedBorrowBalanceOnPool = borrowBalanceOnPool.mul(IVToken(vUsdc).borrowIndex());
        uint256 expectedTotalBorrowBalance = expectedBorrowBalanceInP2P + expectedBorrowBalanceOnPool;

        assertEq(userBorrowBalance.onPool, expectedBorrowBalanceOnPool, "On pool borrow balance");
        assertEq(userBorrowBalance.inP2P, expectedBorrowBalanceInP2P, "P2P borrow balance");
        assertEq(userBorrowBalance.totalBalance, expectedTotalBorrowBalance, "Total borrow balance");
    }

    function testUserBalanceWithMatching() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = (amount / 2);

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, toBorrow);

        uint256 toMatch = toBorrow / 2;
        supplier1.approve(usdc, toMatch);
        supplier1.supply(vUsdc, toMatch);

        // borrower 1 supply balance (not matched)
        UserBalance memory userSupplyBalance;

        (userSupplyBalance.onPool, userSupplyBalance.inP2P, userSupplyBalance.totalBalance) =
            lens.getCurrentSupplyBalanceInOf(vDai, address(borrower1));

        (uint256 supplyBalanceInP2P, uint256 supplyBalanceOnPool) = evoq.supplyBalanceInOf(vDai, address(borrower1));

        uint256 expectedSupplyBalanceInP2P = supplyBalanceInP2P.mul(evoq.p2pSupplyIndex(vDai));
        uint256 expectedSupplyBalanceOnPool = supplyBalanceOnPool.mul(IVToken(vDai).exchangeRateCurrent());

        assertEq(userSupplyBalance.onPool, expectedSupplyBalanceOnPool, "On pool supply balance");
        assertEq(userSupplyBalance.inP2P, expectedSupplyBalanceInP2P, "P2P supply balance");
        assertEq(
            userSupplyBalance.totalBalance,
            expectedSupplyBalanceOnPool + expectedSupplyBalanceInP2P,
            "Total supply balance"
        );

        // borrower 1 borrow balance (partially matched)
        UserBalance memory userBorrowBalance;

        (userBorrowBalance.onPool, userBorrowBalance.inP2P, userBorrowBalance.totalBalance) =
            lens.getCurrentBorrowBalanceInOf(vUsdc, address(borrower1));

        (uint256 borrowBalanceInP2P, uint256 borrowBalanceOnPool) = evoq.borrowBalanceInOf(vUsdc, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = borrowBalanceInP2P.mul(evoq.p2pBorrowIndex(vUsdc));
        uint256 expectedBorrowBalanceOnPool = borrowBalanceOnPool.mul(IVToken(vUsdc).borrowIndex());

        assertEq(userBorrowBalance.onPool, expectedBorrowBalanceOnPool, "On pool borrow balance");
        assertEq(userBorrowBalance.inP2P, expectedBorrowBalanceInP2P, "P2P borrow balance");
        assertEq(
            userBorrowBalance.totalBalance,
            expectedBorrowBalanceOnPool + expectedBorrowBalanceInP2P,
            "Total borrow balance"
        );

        // borrower 2 supply balance (pure supplier fully matched)
        UserBalance memory matchedSupplierSupplyBalance;

        (
            matchedSupplierSupplyBalance.onPool,
            matchedSupplierSupplyBalance.inP2P,
            matchedSupplierSupplyBalance.totalBalance
        ) = lens.getCurrentSupplyBalanceInOf(vUsdc, address(supplier1));

        (supplyBalanceInP2P, supplyBalanceOnPool) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));

        expectedSupplyBalanceInP2P = supplyBalanceInP2P.mul(evoq.p2pSupplyIndex(vUsdc));
        expectedSupplyBalanceOnPool = supplyBalanceOnPool.mul(IVToken(vUsdc).exchangeRateCurrent());

        assertEq(matchedSupplierSupplyBalance.onPool, expectedSupplyBalanceOnPool, "On pool matched supplier balance");
        assertEq(matchedSupplierSupplyBalance.inP2P, expectedSupplyBalanceInP2P, "P2P matched supplier balance");
        assertEq(
            matchedSupplierSupplyBalance.totalBalance,
            expectedSupplyBalanceOnPool + expectedSupplyBalanceInP2P,
            "Total matched supplier balance"
        );
    }

    function testMaxCapacitiesWithNothingWithSupplyWithMultipleAssetsAndBorrow() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));
        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        Types.AssetLiquidityData memory assetDataCUsdc =
            lens.getUserLiquidityDataForAsset(address(borrower1), vUsdc, true, oracle);

        Types.AssetLiquidityData memory assetDataCDai =
            lens.getUserLiquidityDataForAsset(address(borrower1), vDai, true, oracle);

        Types.AssetLiquidityData memory assetDataCUsdt =
            lens.getUserLiquidityDataForAsset(address(borrower1), vUsdt, true, oracle);

        (uint256 withdrawableDai,) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);
        (uint256 withdrawableUsdc,) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdc);
        (, uint256 borrowableUsdt) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdt);

        uint256 expectedBorrowableUsdt =
            (assetDataCDai.maxDebtUsd + assetDataCUsdc.maxDebtUsd).div(assetDataCUsdt.underlyingPrice);

        assertApproxEqAbs(
            withdrawableUsdc, getBalanceOnVenus((amount), IVToken(vUsdc).exchangeRateCurrent()), 1, "withdrawable USDC"
        );
        assertApproxEqAbs(
            withdrawableDai, getBalanceOnVenus(amount, IVToken(vDai).exchangeRateCurrent()), 1, "withdrawable DAI"
        );
        assertEq(borrowableUsdt, expectedBorrowableUsdt, "borrowable USDT before");

        uint256 toBorrow = (100 ether);
        borrower1.borrow(vUsdt, toBorrow);

        (, uint256 newBorrowableUsdt) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdt);

        expectedBorrowableUsdt -= toBorrow;

        assertApproxEqAbs(newBorrowableUsdt, expectedBorrowableUsdt, 3, "borrowable USDT after");
    }

    function testUserBalanceStatesWithSupplyAndBorrow() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = (amount / 2);

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vUsdc, toBorrow);

        UserBalanceStates memory states;
        UserBalanceStates memory expectedStates;

        (states.collateralUsd, states.debtUsd, states.maxDebtUsd) =
            lens.getUserBalanceStates(address(borrower1), new address[](0));

        uint256 underlyingPriceUsdc = oracle.getUnderlyingPrice(vUsdc);

        // DAI data
        (, uint256 collateralFactor,) = comptroller.markets(vDai);
        uint256 underlyingPriceDai = oracle.getUnderlyingPrice(vDai);
        expectedStates.collateralUsd =
            getBalanceOnVenus(amount, IVToken(vDai).exchangeRateStored()).mul(underlyingPriceDai);

        expectedStates.debtUsd = getBalanceOnVenus(toBorrow, IVToken(vUsdc).borrowIndex()).mul(underlyingPriceUsdc);
        expectedStates.maxDebtUsd = expectedStates.collateralUsd.mul(collateralFactor);

        assertEq(states.collateralUsd, expectedStates.collateralUsd, "Collateral Value");
        assertEq(states.maxDebtUsd, expectedStates.maxDebtUsd, "Max Debt Value");
        assertEq(states.debtUsd, expectedStates.debtUsd, "Debt Value");
    }

    function testUserBalanceStatesWithSupplyAndBorrowWithMultipleAssets() public {
        uint256 amount = 10_000 ether;
        uint256 toBorrow = 100 ether;

        createMarket(vCake);

        // Avoid stack too deep error
        UserBalanceStates memory states;
        UserBalanceStates memory expectedStates;

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));
        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        borrower1.borrow(vCake, toBorrow);
        borrower1.borrow(vUsdt, (toBorrow));

        // USDC data
        uint256 collateralValueToAdd =
            getBalanceOnVenus((amount), IVToken(vUsdc).exchangeRateStored()).mul(oracle.getUnderlyingPrice(vUsdc));
        expectedStates.collateralUsd += collateralValueToAdd;
        (, uint256 collateralFactor,) = comptroller.markets(vUsdc);
        expectedStates.maxDebtUsd += collateralValueToAdd.mul(collateralFactor);

        // DAI data
        collateralValueToAdd =
            getBalanceOnVenus(amount, IVToken(vDai).exchangeRateStored()).mul(oracle.getUnderlyingPrice(vDai));
        expectedStates.collateralUsd += collateralValueToAdd;
        (, collateralFactor,) = comptroller.markets(vDai);
        expectedStates.maxDebtUsd += collateralValueToAdd.mul(collateralFactor);

        // CAKE
        expectedStates.debtUsd +=
            getBalanceOnVenus(toBorrow, IVToken(vCake).borrowIndex()).mul(oracle.getUnderlyingPrice(vCake));
        // USDT
        expectedStates.debtUsd +=
            getBalanceOnVenus((toBorrow), IVToken(vUsdt).borrowIndex()).mul(oracle.getUnderlyingPrice(vUsdt));

        (states.collateralUsd, states.debtUsd, states.maxDebtUsd) =
            lens.getUserBalanceStates(address(borrower1), new address[](0));

        assertEq(states.collateralUsd, expectedStates.collateralUsd, "Collateral Value");
        assertEq(states.debtUsd, expectedStates.debtUsd, "Debt Value");
        assertEq(states.maxDebtUsd, expectedStates.maxDebtUsd, "Max Debt Value");
    }

    /// This test is to check that a call to getUserLiquidityDataForAsset with USDT doesn't end
    ///   with error "Division or modulo by zero", as Venus returns 0 for USDT collateralFactor.
    /*
    function testLiquidityDataForUSDT() public {
        uint256 usdtAmount = (10_000 ether);

        deal(usdt, address(borrower1), usdtAmount);
        borrower1.approve(usdt, usdtAmount);
        borrower1.supply(vUsdt, usdtAmount);

        (uint256 withdrawableUsdt, uint256 borrowableUsdt) = lens
            .getUserMaxCapacitiesForAsset(address(borrower1), vUsdt);

        uint256 depositedUsdtAmount = getBalanceOnVenus(
            usdtAmount,
            IVToken(vUsdt).exchangeRateStored()
        );

        assertEq(withdrawableUsdt, depositedUsdtAmount, "withdrawable USDT");
        assertEq(borrowableUsdt, 0, "borrowable USDT");

        (uint256 withdrawableDai, uint256 borrowableDai) = lens
            .getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        assertEq(withdrawableDai, 0, "withdrawable DAI");
        assertEq(borrowableDai, 0, "borrowable DAI");
    }
    */

    function testLiquidityDataFailsWhenOracleFails() public {
        uint256 daiAmount = 1 ether;

        borrower1.approve(dai, daiAmount);
        borrower1.supply(vDai, daiAmount);

        createAndSetCustomPriceOracle().setDirectPrice(dai, 0);

        hevm.expectRevert(abi.encodeWithSignature("VenusOracleFailed()"));
        lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);
    }

    function testLiquidityDataWithMultipleAssetsAndUSDT() public {
        Indexes memory indexes;
        uint256 amount = 10_000 ether;
        uint256 toBorrow = (100 ether);

        deal(usdt, address(borrower1), (amount));
        borrower1.approve(usdt, (amount));
        indexes.index1 = IVToken(vUsdt).exchangeRateCurrent();
        borrower1.supply(vUsdt, (amount));
        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        borrower1.borrow(vUsdc, toBorrow);
        indexes.index2 = IVToken(vUsdt).exchangeRateCurrent();
        borrower1.borrow(vUsdt, toBorrow);

        // Avoid stack too deep error.
        UserBalanceStates memory states;
        UserBalanceStates memory expectedStates;

        (states.collateralUsd, states.debtUsd, states.maxDebtUsd) =
            lens.getUserBalanceStates(address(borrower1), new address[](0));

        // We must take into account that not everything is on pool as borrower1 is matched to itself.
        uint256 total;

        {
            uint256 onPool = (amount).div(indexes.index1);
            uint256 matchedInP2P = toBorrow.div(evoq.p2pSupplyIndex(vUsdt));
            uint256 onPoolAfter = onPool - toBorrow.div(indexes.index2);
            total = onPoolAfter.mul(indexes.index2) + matchedInP2P.mul(evoq.p2pSupplyIndex(vUsdt));
        }

        // USDT data
        (, uint256 collateralFactor,) = comptroller.markets(vUsdt);
        uint256 underlyingPrice = oracle.getUnderlyingPrice(vUsdt);

        uint256 collateralValueToAdd = total.mul(underlyingPrice);
        expectedStates.collateralUsd += collateralValueToAdd;
        expectedStates.maxDebtUsd += collateralValueToAdd.mul(collateralFactor);

        // DAI data
        (, collateralFactor,) = comptroller.markets(vDai);
        collateralValueToAdd =
            getBalanceOnVenus(amount, IVToken(vDai).exchangeRateCurrent()).mul(oracle.getUnderlyingPrice(vDai));
        expectedStates.collateralUsd += collateralValueToAdd;
        expectedStates.maxDebtUsd += collateralValueToAdd.mul(collateralFactor);

        // USDC data
        expectedStates.debtUsd +=
            getBalanceOnVenus(toBorrow, IVToken(vUsdc).borrowIndex()).mul(oracle.getUnderlyingPrice(vUsdc));

        // USDT data
        expectedStates.debtUsd +=
            getBalanceOnVenus(toBorrow, IVToken(vUsdt).borrowIndex()).mul(oracle.getUnderlyingPrice(vUsdt));

        assertApproxEqAbs(states.collateralUsd, expectedStates.collateralUsd, 1e4, "Collateral Value");
        assertApproxEqAbs(states.debtUsd, expectedStates.debtUsd, 1e9, "Debt Value");
        assertApproxEqAbs(states.maxDebtUsd, expectedStates.maxDebtUsd, 1e5, "Max Debt Value");
    }

    function testUserHypotheticalBalanceStatesUnenteredMarket() public {
        uint256 amount = 10_001 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        uint256 hypotheticalBorrow = 500e6;
        (uint256 debtValue, uint256 maxDebtValue) =
            lens.getUserHypotheticalBalanceStates(address(borrower1), vUsdc, 0, amount / 2, hypotheticalBorrow, 0);

        (, uint256 daiCollateralFactor,) = comptroller.markets(vDai);

        assertApproxEqAbs(
            maxDebtValue, amount.mul(oracle.getUnderlyingPrice(vDai)).mul(daiCollateralFactor), 1e9, "maxDebtValue"
        );
        assertEq(debtValue, hypotheticalBorrow.mul(oracle.getUnderlyingPrice(vUsdc)), "debtValue");
    }

    function testUserHypotheticalBalanceStatesAfterUnauthorisedBorrowWithdraw() public {
        uint256 amount = 10_001 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);

        uint256 hypotheticalWithdraw = 2 * amount;
        uint256 hypotheticalBorrow = amount;
        (uint256 debtValue, uint256 maxDebtValue) = lens.getUserHypotheticalBalanceStates(
            address(borrower1), vDai, 0, hypotheticalWithdraw, hypotheticalBorrow, 0
        );

        assertEq(maxDebtValue, 0, "maxDebtValue");
        assertEq(debtValue, hypotheticalBorrow.mul(oracle.getUnderlyingPrice(vDai)), "debtValue");
    }

    function testGetMainMarketData() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(dai, amount);
        borrower1.supply(vDai, amount);
        borrower1.borrow(vDai, amount / 2);

        (,, uint256 p2pSupplyAmount, uint256 p2pBorrowAmount, uint256 poolSupplyAmount, uint256 poolBorrowAmount) =
            lens.getMainMarketData(vDai);

        assertApproxEqAbs(p2pSupplyAmount, p2pBorrowAmount, 1e9);
        assertApproxEqAbs(p2pSupplyAmount, amount / 2, 1e9);
        assertApproxEqAbs(poolSupplyAmount, amount / 2, 1e9);
        assertApproxEqAbs(poolBorrowAmount, 0, 1e4);
    }

    function testGetMarketConfiguration() public {
        (
            address underlying,
            bool isCreated,
            bool p2pDisabled,
            uint16 reserveFactor,
            uint16 p2pIndexCursor,
            uint256 collateralFactor
        ) = lens.getMarketConfiguration(vDai);
        assertTrue(underlying == IVToken(vDai).underlying());

        (bool isCreated_) = evoq.marketStatus(vDai);

        assertTrue(isCreated == isCreated_);
        assertTrue(p2pDisabled == evoq.p2pDisabled(vDai));

        (uint16 expectedReserveFactor, uint16 expectedP2PIndexCursor) = evoq.marketParameters(vDai);
        assertTrue(reserveFactor == expectedReserveFactor);
        assertTrue(p2pIndexCursor == expectedP2PIndexCursor);
        (, uint256 expectedCollateralFactor,) = evoq.comptroller().markets(vDai);
        assertTrue(collateralFactor == expectedCollateralFactor);
    }

    function testGetOutdatedIndexes() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + (31 * 24 * 60 * 4));
        Types.Indexes memory indexes = lens.getIndexes(vDai, false);

        assertEq(indexes.p2pSupplyIndex, evoq.p2pSupplyIndex(vDai), "p2p supply indexes different");
        assertEq(indexes.p2pBorrowIndex, evoq.p2pBorrowIndex(vDai), "p2p borrow indexes different");

        assertEq(indexes.poolSupplyIndex, IVToken(vDai).exchangeRateStored(), "pool supply indexes different");
        assertEq(indexes.poolBorrowIndex, IVToken(vDai).borrowIndex(), "pool borrow indexes different");
    }

    function testGetUpdatedIndexes() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + (31 * 24 * 60 * 4));
        Types.Indexes memory indexes = lens.getIndexes(vDai, true);

        evoq.updateP2PIndexes(vDai);
        assertEq(indexes.p2pSupplyIndex, evoq.p2pSupplyIndex(vDai), "p2p supply indexes different");
        assertEq(indexes.p2pBorrowIndex, evoq.p2pBorrowIndex(vDai), "p2p borrow indexes different");

        assertEq(indexes.poolSupplyIndex, IVToken(vDai).exchangeRateCurrent(), "pool supply indexes different");
        assertEq(indexes.poolBorrowIndex, IVToken(vDai).borrowIndex(), "pool borrow indexes different");
    }

    function testGetUpdatedP2PIndexesWithSupplyDelta() public {
        _createSupplyDelta();
        hevm.roll(block.timestamp + (365 * 24 * 60 * 4));
        Types.Indexes memory indexes = lens.getIndexes(vDai, true);

        evoq.updateP2PIndexes(vDai);
        assertApproxEqAbs(indexes.p2pBorrowIndex, evoq.p2pBorrowIndex(vDai), 1);
        assertApproxEqAbs(indexes.p2pSupplyIndex, evoq.p2pSupplyIndex(vDai), 1);
    }

    function testGetUpdatedP2PIndexesWithBorrowDelta() public {
        _createBorrowDelta();
        hevm.roll(block.timestamp + (365 * 24 * 60 * 4));
        Types.Indexes memory indexes = lens.getIndexes(vDai, true);

        evoq.updateP2PIndexes(vDai);
        assertApproxEqAbs(indexes.p2pBorrowIndex, evoq.p2pBorrowIndex(vDai), 1);
        assertApproxEqAbs(indexes.p2pSupplyIndex, evoq.p2pSupplyIndex(vDai), 1);
    }

    function testGetUpdatedP2PSupplyIndex() public {
        hevm.roll(block.number + (24 * 60 * 4));
        uint256 p2pSupplyIndex = lens.getCurrentP2PSupplyIndex(vDai);

        evoq.updateP2PIndexes(vDai);
        assertEq(p2pSupplyIndex, evoq.p2pSupplyIndex(vDai));
    }

    function testGetUpdatedP2PBorrowIndex() public {
        hevm.roll(block.number + (24 * 60 * 4));
        uint256 p2pBorrowIndex = lens.getCurrentP2PBorrowIndex(vDai);

        evoq.updateP2PIndexes(vDai);
        assertEq(p2pBorrowIndex, evoq.p2pBorrowIndex(vDai));
    }

    function testGetUpdatedP2PBorrowIndexWithDelta() public {
        _createBorrowDelta();
        hevm.roll(block.number + (365 * 24 * 60 * 4));
        uint256 p2pBorrowIndex = lens.getCurrentP2PBorrowIndex(vDai);

        evoq.updateP2PIndexes(vDai);
        assertEq(p2pBorrowIndex, evoq.p2pBorrowIndex(vDai));
    }

    function testGetUpdatedIndexesWithTransferToCTokenContract() public {
        hevm.roll(block.number + (31 * 24 * 60 * 4));

        hevm.prank(address(supplier1));
        ERC20(dai).transfer(vDai, 100 ether);

        hevm.roll(block.number + 1);

        Types.Indexes memory indexes = lens.getIndexes(vDai, true);

        evoq.updateP2PIndexes(vDai);
        assertEq(indexes.p2pSupplyIndex, evoq.p2pSupplyIndex(vDai), "p2p supply indexes different");
        assertEq(indexes.p2pBorrowIndex, evoq.p2pBorrowIndex(vDai), "p2p borrow indexes different");
        assertEq(indexes.poolSupplyIndex, IVToken(vDai).exchangeRateCurrent(), "pool supply indexes different");
        assertEq(indexes.poolBorrowIndex, IVToken(vDai).borrowIndex(), "pool borrow indexes different");
    }

    function _createSupplyDelta() public {
        uint256 amount = 1 ether;
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);

        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, amount / 2);
        borrower1.borrow(vDai, amount / 4);

        moveOneBlockForwardBorrowRepay();

        (uint64 supply, uint64 borrow, uint64 withdraw, uint64 repay) = evoq.defaultMaxGasForMatching();

        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        borrower1.repay(vDai, type(uint256).max);

        setDefaultMaxGasForMatchingHelper(supply, borrow, withdraw, repay);
    }

    function _createBorrowDelta() public {
        uint256 amount = 1 ether;
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);

        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, amount / 2);
        borrower1.borrow(vDai, amount / 4);

        (uint64 supply, uint64 borrow, uint64 withdraw, uint64 repay) = evoq.defaultMaxGasForMatching();

        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        supplier1.withdraw(vDai, type(uint256).max);

        setDefaultMaxGasForMatchingHelper(supply, borrow, withdraw, repay);
    }

    function testGetAllMarkets() public {
        address[] memory lensMarkets = lens.getAllMarkets();
        address[] memory evoqMarkets = evoq.getAllMarkets();

        for (uint256 i; i < lensMarkets.length; i++) {
            assertEq(evoqMarkets[i], lensMarkets[i]);
        }
    }

    function testGetEnteredMarkets() public {
        uint256 amount = 1e12;
        supplier1.approve(dai, amount);
        supplier1.approve(usdc, amount);
        supplier1.approve(usdt, amount);
        supplier1.supply(vDai, amount);
        supplier1.supply(vUsdc, amount);
        supplier1.supply(vUsdt, amount);

        address[] memory lensEnteredMarkets = lens.getEnteredMarkets(address(supplier1));
        address[] memory evoqEnteredMarkets = evoq.getEnteredMarkets(address(supplier1));

        for (uint256 i; i < lensEnteredMarkets.length; i++) {
            assertEq(evoqEnteredMarkets[i], lensEnteredMarkets[i]);
        }
    }

    function testIsLiquidatableFalse() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        assertFalse(lens.isLiquidatable(address(borrower1), new address[](0)));
    }

    function testIsLiquidatableTrue() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        createAndSetCustomPriceOracle().setDirectPrice(usdc, oracle.getUnderlyingPrice(vUsdc) / 2);

        assertTrue(lens.isLiquidatable(address(borrower1), new address[](0)));
    }

    function testHealthFactorBelow1() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, 0.5e18);
        oracle.setUnderlyingPrice(vDai, 1e18);

        bool isLiquidatable = lens.isLiquidatable(address(borrower1), new address[](0));
        uint256 healthFactor = lens.getUserHealthFactor(address(borrower1), new address[](0));

        assertTrue(isLiquidatable);
        assertLt(healthFactor, 1e18);
    }

    function testHealthFactorAbove1() public {
        uint256 amount = 10_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, 1e18);
        oracle.setUnderlyingPrice(vDai, 1e18);

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        (, uint256 usdcCollateralFactor,) = comptroller.markets(vUsdc);

        uint256 healthFactor = lens.getUserHealthFactor(address(borrower1), new address[](0));
        uint256 expectedHealthFactor = (2 * amount).mul(usdcCollateralFactor).div(amount);

        assertApproxEqAbs(healthFactor, expectedHealthFactor, 1e8);
    }

    function testHealthFactorShouldBeInfinityForPureSuppliers() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(usdc, (2 * amount));
        supplier1.supply(vUsdc, (2 * amount));

        uint256 healthFactor = lens.getUserHealthFactor(address(supplier1), new address[](0));

        assertEq(healthFactor, type(uint256).max);
    }

    function testHealthFactorAbove1WhenHalfMatched() public {
        uint256 amount = 10_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, 1e18);
        oracle.setUnderlyingPrice(vDai, 1e18);

        supplier1.approve(dai, amount / 2);
        supplier1.supply(vDai, amount / 2);

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        (, uint256 usdcCollateralFactor,) = comptroller.markets(vUsdc);

        uint256 healthFactor = lens.getUserHealthFactor(address(borrower1), new address[](0));
        uint256 expectedHealthFactor = (2 * amount).mul(usdcCollateralFactor).div(amount);

        assertApproxEqAbs(healthFactor, expectedHealthFactor, 1e8);
    }

    function testHealthFactorAbove1WithUpdatedMarkets() public {
        uint256 amount = 10_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, 1e18);
        oracle.setUnderlyingPrice(vDai, 1e18);

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 10_000);

        address[] memory updatedMarkets = new address[](1);
        uint256 healthFactorNotUpdated = lens.getUserHealthFactor(address(borrower1), updatedMarkets);

        updatedMarkets[0] = vUsdc;

        uint256 healthFactorUsdcUpdated = lens.getUserHealthFactor(address(borrower1), updatedMarkets);

        updatedMarkets[0] = vDai;

        uint256 healthFactorDaiUpdated = lens.getUserHealthFactor(address(borrower1), updatedMarkets);

        assertGt(healthFactorUsdcUpdated, healthFactorNotUpdated, "health factor lower when updating vUsdc");
        assertLt(healthFactorDaiUpdated, healthFactorNotUpdated, "health factor higher when updating vDai");
    }

    function testHealthFactorEqual1() public {
        uint256 amount = 1_000 ether;

        SimplePriceOracle oracle = createAndSetCustomPriceOracle();
        oracle.setUnderlyingPrice(vUsdc, 1e18);
        oracle.setUnderlyingPrice(vDai, 1e18);

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        uint256 borrower1HealthFactor = lens.getUserHealthFactor(address(borrower1), new address[](0));

        borrower2.approve(usdc, (2 * amount));
        borrower2.supply(vUsdc, (2 * amount));
        borrower2.borrow(vDai, amount.mul(borrower1HealthFactor));

        uint256 borrower2HealthFactor = lens.getUserHealthFactor(address(borrower2), new address[](0));

        assertApproxEqAbs(borrower2HealthFactor, 1e18, 2);
    }

    function testHealthFactorEqual1WhenBorrowingMaxCapacity() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1000);

        (, uint256 borrowable) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai);

        borrower1.borrow(vDai, borrowable);

        uint256 healthFactor = lens.getUserHealthFactor(address(borrower1), new address[](0));

        assertEq(healthFactor, 1e18);
    }

    function testComputeLiquidation() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        createAndSetCustomPriceOracle().setDirectPrice(usdc, 1);

        assertApproxEqAbs(
            lens.computeLiquidationRepayAmount(address(borrower1), vDai, vUsdc, new address[](0)), 0, 2 * 1e4
        );
    }

    function testComputeLiquidation2() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        assertEq(lens.computeLiquidationRepayAmount(address(borrower1), vDai, vUsdc, new address[](0)), 0);
    }

    function testComputeLiquidation3() public {
        uint256 amount = 10_000 ether;

        createAndSetCustomPriceOracle().setDirectPrice(usdc, (oracle.getUnderlyingPrice(vDai) * 2));

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));
        borrower1.borrow(vDai, amount);

        createAndSetCustomPriceOracle().setDirectPrice(usdc, ((oracle.getUnderlyingPrice(vDai) * 79) / 100));

        assertApproxEqAbs(
            lens.computeLiquidationRepayAmount(address(borrower1), vDai, vUsdc, new address[](0)),
            amount.mul(comptroller.closeFactorMantissa()),
            1
        );
    }

    function testComputeLiquidation4() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        createAndSetCustomPriceOracle().setDirectPrice(
            usdc,
            (oracle.getUnderlyingPrice(vDai) / 2) // Setting the value of the collateral at the same value as the debt.
        );

        assertTrue(lens.isLiquidatable(address(borrower1), new address[](0)));

        assertApproxEqAbs(
            lens.computeLiquidationRepayAmount(address(borrower1), vDai, vUsdc, new address[](0)), amount / 2, 1
        );
    }

    function testLiquidationWithUpdatedPoolIndexes() public {
        uint256 amount = 10_000 ether;

        (, uint256 collateralFactor,) = comptroller.markets(vUsdc);

        borrower1.approve(usdc, (amount));
        borrower1.supply(vUsdc, (amount));
        borrower1.borrow(vDai, amount.mul(collateralFactor) - 10 ether);

        address[] memory updatedMarkets = new address[](2);
        assertFalse(lens.isLiquidatable(address(borrower1), updatedMarkets), "borrower is already liquidatable");

        hevm.roll(block.number + (31 * 24 * 60 * 4));

        assertFalse(lens.isLiquidatable(address(borrower1), updatedMarkets), "borrower is already liquidatable");

        updatedMarkets[0] = address(vDai);
        updatedMarkets[1] = address(vUsdc);

        // TODO: accrue interest -> expect lower health factor.
        // but if supply rate is higher than borrow rate, health factor could be higher.
        // Venus USDC supply rate is high.

        // assertTrue(
        //     lens.isLiquidatable(address(borrower1), updatedMarkets),
        //     "borrower is not liquidatable with virtually updated pool indexes"
        // );

        IVToken(vUsdc).accrueInterest();
        IVToken(vDai).accrueInterest();
        // assertTrue(
        //     lens.isLiquidatable(address(borrower1), new address[](0)),
        //     "borrower is not liquidatable with updated pool indexes"
        // );
    }

    function testLiquidatableWithUpdatedP2PIndexes() public {
        uint256 amount = 10_000 ether;

        supplier2.approve(dai, amount);
        supplier2.supply(vDai, amount);

        (, uint256 collateralFactor,) = comptroller.markets(vUsdc);

        borrower1.approve(usdc, amount);
        borrower1.supply(vUsdc, amount);
        borrower1.borrow(vDai, amount.mul(collateralFactor) - 10 ether);

        address[] memory updatedMarkets = new address[](2);
        assertFalse(lens.isLiquidatable(address(borrower1), updatedMarkets), "borrower is already liquidatable");

        hevm.roll(block.number + (31 * 24 * 60 * 4));

        assertFalse(lens.isLiquidatable(address(borrower1), updatedMarkets), "borrower is already liquidatable");

        updatedMarkets[0] = address(vDai);
        updatedMarkets[1] = address(vUsdc);

        // TODO: accrue interest -> expect lower health factor.
        // but if supply rate is higher than borrow rate, health factor could be higher.
        // Venus USDC supply rate is high.

        // assertTrue(
        //     lens.isLiquidatable(address(borrower1), updatedMarkets),
        //     "borrower is not liquidatable with virtually updated p2p indexes"
        // );

        evoq.updateP2PIndexes(vUsdc);
        evoq.updateP2PIndexes(vDai);
        // assertTrue(
        //     lens.isLiquidatable(address(borrower1), new address[](0)),
        //     "borrower is not liquidatable with updated p2p indexes"
        // );
    }

    function testLiquidation(uint256 _amount, uint80 _collateralPrice) internal {
        uint256 amount = _amount + 1e14;
        uint256 collateralPrice = uint256(_collateralPrice) + 1;

        // this is necessary to avoid venus reverting redeem because amount in USD is near zero
        supplier2.approve(usdc, 100e18);
        supplier2.supply(vUsdc, 100e18);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(supplier1));

        borrower1.approve(dai, 2 * amount);
        borrower1.supply(vDai, 2 * amount);
        borrower1.borrow(vUsdc, (amount));

        moveOneBlockForwardBorrowRepay();
        createAndSetCustomPriceOracle().setDirectPrice(dai, collateralPrice);

        (uint256 collateralValue, uint256 debtValue, uint256 maxDebtValue) =
            lens.getUserBalanceStates(address(borrower1), new address[](0));

        uint256 borrowedPrice = oracle.getUnderlyingPrice(vUsdc);
        uint256 toRepay = lens.computeLiquidationRepayAmount(address(borrower1), vUsdc, vDai, new address[](0));

        if (debtValue <= maxDebtValue) {
            assertEq(toRepay, 0, "Should return 0 when the position is solvent");
            return;
        }

        if (toRepay != 0) {
            supplier1.approve(usdc, type(uint256).max);

            // evade rounding error when calculate amountToSeize in liquidateLogic
            uint256 minRoundingError = 1e6;

            do {
                if (toRepay > minRoundingError) {
                    supplier1.liquidate(vUsdc, vDai, address(borrower1), toRepay);
                    assertGt(ERC20(dai).balanceOf(address(supplier1)), balanceBefore, "balance did not increase");

                    balanceBefore = ERC20(dai).balanceOf(address(supplier1));
                    toRepay = lens.computeLiquidationRepayAmount(address(borrower1), vUsdc, vDai, new address[](0));
                }
            } while (lens.isLiquidatable(address(borrower1), new address[](0)) && toRepay > minRoundingError);

            // either the liquidatee's position (borrow value divided by supply value) was under the [1 / liquidationIncentive] threshold and returned to a solvent position
            if (collateralValue.div(comptroller.liquidationIncentiveMantissa()) > debtValue) {
                assertFalse(lens.isLiquidatable(address(borrower1), new address[](0)));
            } else {
                // or the liquidator has drained all the collateral
                (collateralValue,,) = lens.getUserBalanceStates(address(borrower1), new address[](0));
                assertApproxEqAbs(
                    collateralValue.div(borrowedPrice).div(comptroller.liquidationIncentiveMantissa()),
                    0,
                    minRoundingError
                );
                assertApproxEqAbs(toRepay, 0, minRoundingError, "toRepay");
            }
        } else {
            // liquidator cannot repay anything iff 1 wei of borrow is greater than the repayable collateral + the liquidation bonus
            assertEq(collateralValue.div(borrowedPrice).div(comptroller.liquidationIncentiveMantissa()), 0);
        }
    }

    function testFuzzLiquidation(uint64 _amount, uint80 _collateralPrice) public {
        testLiquidation(uint256(_amount), _collateralPrice);
    }

    function testFuzzLiquidationUnderIncentiveThreshold(uint64 _amount) public {
        testLiquidation(uint256(_amount), 0.501 ether);
    }

    function testFuzzLiquidationAboveIncentiveThreshold(uint64 _amount) public {
        testLiquidation(uint256(_amount), 0.55 ether);
    }

    /**
     * @dev Because of rounding errors, a liquidatable position worth less than 1e-5 USD cannot get liquidated in practice
     * Explanation with amount = 1e13 (1e-5 USDC borrowed):
     * 0. Before changing the collateralPrice, position is not liquidatable:
     * - debtValue = 9e-6 USD (venus rounding error, should be 1e-5 USD)
     * - collateralValue = 2e-5 USD (+ some dust because of rounding errors, should be 2e-5 USD)
     * 1. collateralPrice is set to 0.501 ether, position is under the [1 / liquidationIncentive] threshold:
     * - debtValue = 9e-6 USD (venus rounding error, should be 1e-5 USD => position should be above the [1 / liquidationIncentive] threshold)
     * - collateralValue = 1.001e-5 USD
     * 2. Liquidation happens, position is now above the [1 / liquidationIncentive] threshold:
     * - toRepay = 4e-6 USD (debtValue * closeFactor = 4.5e-6 truncated to 4e-6)
     * - debtValue = 6e-6 (because of p2p units rounding errors: 9e-6 - 4e-6 ~= 6e-6)
     * 3. After several liquidations, the position is still considered liquidatable but no collateral can be liquidated:
     * - debtValue = 1e-6 USD
     * - collateralValue = 1e-6 USD (+ some dust)
     */
    function testNoRepayLiquidation() public {
        testLiquidation(0, 0.5 ether);
    }

    function testIsLiquidatableDeprecatedMarket() public {
        uint256 amount = 1_000 ether;

        borrower1.approve(dai, 2 * amount);
        borrower1.supply(vDai, 2 * amount);
        borrower1.borrow(vUsdc, amount);

        assertFalse(lens.isLiquidatable(address(borrower1), vUsdc, new address[](0)));

        evoq.setIsBorrowPaused(vUsdc, true);
        evoq.setIsDeprecated(vUsdc, true);

        assertTrue(lens.isLiquidatable(address(borrower1), vUsdc, new address[](0)));
    }

    struct Amounts {
        uint256 totalP2PSupply;
        uint256 totalPoolSupply;
        uint256 totalSupply;
        uint256 totalP2PBorrow;
        uint256 totalPoolBorrow;
        uint256 totalBorrow;
        uint256 daiP2PSupply;
        uint256 daiPoolSupply;
        uint256 daiP2PBorrow;
        uint256 daiPoolBorrow;
        uint256 bnbP2PSupply;
        uint256 bnbPoolSupply;
        uint256 bnbP2PBorrow;
        uint256 bnbPoolBorrow;
    }

    struct SupplyBorrowIndexes {
        uint256 bnbPoolSupplyIndexBefore;
        uint256 daiP2PSupplyIndexBefore;
        uint256 daiP2PBorrowIndexBefore;
        uint256 bnbPoolSupplyIndexAfter;
        uint256 daiPoolSupplyIndexAfter;
        uint256 daiP2PSupplyIndexAfter;
        uint256 daiP2PBorrowIndexAfter;
    }

    function testTotalSupplyBorrowWithHalfSupplyDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        SupplyBorrowIndexes memory indexes;
        indexes.bnbPoolSupplyIndexBefore = IVToken(vBnb).exchangeRateCurrent();
        indexes.daiP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vDai);

        hevm.roll(block.number + 1);

        borrower1.approve(dai, amount / 2);
        borrower1.repay(vDai, amount / 2);

        {
            SimplePriceOracle oracle = createAndSetCustomPriceOracle();
            oracle.setUnderlyingPrice(vBnb, 2 ether);
            oracle.setUnderlyingPrice(vDai, 1 ether);
        }

        Amounts memory amounts;

        (amounts.totalP2PSupply, amounts.totalPoolSupply, amounts.totalSupply) = lens.getTotalSupply();
        (amounts.totalP2PBorrow, amounts.totalPoolBorrow, amounts.totalBorrow) = lens.getTotalBorrow();

        (amounts.daiP2PSupply, amounts.daiPoolSupply) = lens.getTotalMarketSupply(vDai);
        (amounts.daiP2PBorrow, amounts.daiPoolBorrow) = lens.getTotalMarketBorrow(vDai);
        (amounts.bnbP2PSupply, amounts.bnbPoolSupply) = lens.getTotalMarketSupply(vBnb);
        (amounts.bnbP2PBorrow, amounts.bnbPoolBorrow) = lens.getTotalMarketBorrow(vBnb);

        indexes.bnbPoolSupplyIndexAfter = IVToken(vBnb).exchangeRateCurrent();
        indexes.daiPoolSupplyIndexAfter = IVToken(vDai).exchangeRateCurrent();
        indexes.daiP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vDai);

        uint256 expectedDaiUSDOnPool =
            (amount / 2).div(indexes.daiPoolSupplyIndexAfter).mul(indexes.daiPoolSupplyIndexAfter); // which is also the supply delta
        uint256 expectedDaiUSDInP2P =
            amount.div(indexes.daiP2PBorrowIndexBefore).mul(indexes.daiP2PBorrowIndexAfter) - expectedDaiUSDOnPool;
        uint256 expectedBnbUSDOnPool =
            2 * amount.div(indexes.bnbPoolSupplyIndexBefore).mul(indexes.bnbPoolSupplyIndexAfter);

        assertApproxEqAbs(
            amounts.totalSupply,
            expectedBnbUSDOnPool + expectedDaiUSDInP2P + expectedDaiUSDOnPool,
            1e6,
            "unexpected total supply"
        );
        assertApproxEqAbs(amounts.totalBorrow, expectedDaiUSDInP2P, 1e9, "unexpected total borrow");

        assertApproxEqAbs(amounts.totalP2PSupply, expectedDaiUSDInP2P, 1e7, "unexpected total p2p supply");
        assertEq(amounts.totalPoolSupply, expectedDaiUSDOnPool + expectedBnbUSDOnPool, "unexpected total pool supply");
        assertApproxEqAbs(amounts.totalP2PBorrow, expectedDaiUSDInP2P, 1e9, "unexpected total p2p borrow");
        assertEq(amounts.totalPoolBorrow, 0, "unexpected total pool borrow");

        assertApproxEqAbs(amounts.daiP2PSupply, expectedDaiUSDInP2P, 1e7, "unexpected dai p2p supply");
        assertApproxEqAbs(amounts.daiP2PBorrow, expectedDaiUSDInP2P, 1e9, "unexpected dai p2p borrow");
        assertEq(amounts.daiPoolSupply, expectedDaiUSDOnPool, "unexpected dai pool supply");
        assertEq(amounts.daiPoolBorrow, 0, "unexpected dai pool borrow");

        assertEq(amounts.bnbP2PSupply, 0, "unexpected bnb p2p supply");
        assertEq(amounts.bnbP2PBorrow, 0, "unexpected bnb p2p borrow");
        assertEq(amounts.bnbPoolSupply, expectedBnbUSDOnPool / 2, "unexpected bnb pool supply");
        assertEq(amounts.bnbPoolBorrow, 0, "unexpected bnb pool borrow");
    }

    function testTotalSupplyBorrowWithHalfBorrowDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        SupplyBorrowIndexes memory indexes;
        indexes.bnbPoolSupplyIndexBefore = IVToken(vBnb).exchangeRateCurrent();
        indexes.daiP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vDai);

        hevm.roll(block.number + 1);

        supplier1.withdraw(vDai, amount / 2);

        {
            SimplePriceOracle oracle = createAndSetCustomPriceOracle();
            oracle.setUnderlyingPrice(vBnb, 2 ether);
            oracle.setUnderlyingPrice(vDai, 1 ether);
        }

        Amounts memory amounts;

        (amounts.totalP2PSupply, amounts.totalPoolSupply, amounts.totalSupply) = lens.getTotalSupply();
        (amounts.totalP2PBorrow, amounts.totalPoolBorrow, amounts.totalBorrow) = lens.getTotalBorrow();

        (amounts.daiP2PSupply, amounts.daiPoolSupply) = lens.getTotalMarketSupply(vDai);
        (amounts.daiP2PBorrow, amounts.daiPoolBorrow) = lens.getTotalMarketBorrow(vDai);
        (amounts.bnbP2PSupply, amounts.bnbPoolSupply) = lens.getTotalMarketSupply(vBnb);
        (amounts.bnbP2PBorrow, amounts.bnbPoolBorrow) = lens.getTotalMarketBorrow(vBnb);

        indexes.bnbPoolSupplyIndexAfter = IVToken(vBnb).exchangeRateCurrent();
        indexes.daiPoolSupplyIndexAfter = IVToken(vDai).exchangeRateCurrent();
        indexes.daiP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vDai);

        uint256 expectedDaiUSDOnPool = amount / 2; // which is also the borrow delta
        uint256 expectedDaiUSDInP2P =
            amount.div(indexes.daiP2PSupplyIndexBefore).mul(indexes.daiP2PSupplyIndexAfter) - expectedDaiUSDOnPool;
        uint256 expectedBnbUSDOnPool =
            2 * amount.div(indexes.bnbPoolSupplyIndexBefore).mul(indexes.bnbPoolSupplyIndexAfter);

        assertApproxEqAbs(
            amounts.totalSupply, expectedBnbUSDOnPool + expectedDaiUSDInP2P, 1e9, "unexpected total supply"
        );
        assertApproxEqAbs(amounts.totalBorrow, expectedDaiUSDInP2P + expectedDaiUSDOnPool, 2, "unexpected total borrow");

        assertApproxEqAbs(amounts.totalP2PSupply, expectedDaiUSDInP2P, 1e9, "unexpected total p2p supply");
        assertApproxEqAbs(amounts.totalPoolSupply, expectedBnbUSDOnPool, 2, "unexpected total pool supply");
        assertApproxEqAbs(amounts.totalP2PBorrow, expectedDaiUSDInP2P, 2, "unexpected total p2p borrow");
        assertApproxEqAbs(amounts.totalPoolBorrow, expectedDaiUSDOnPool, 2, "unexpected total pool borrow");

        assertApproxEqAbs(amounts.daiP2PSupply, expectedDaiUSDInP2P, 1e9, "unexpected dai p2p supply");
        assertApproxEqAbs(amounts.daiP2PBorrow, expectedDaiUSDInP2P, 2, "unexpected dai p2p borrow");
        assertEq(amounts.daiPoolSupply, 0, "unexpected dai pool supply");
        assertApproxEqAbs(amounts.daiPoolBorrow, expectedDaiUSDOnPool, 2, "unexpected dai pool borrow");

        assertEq(amounts.bnbP2PSupply, 0, "unexpected bnb p2p supply");
        assertEq(amounts.bnbP2PBorrow, 0, "unexpected bnb p2p borrow");
        assertEq(amounts.bnbPoolSupply, expectedBnbUSDOnPool / 2, "unexpected bnb pool supply");
        assertEq(amounts.bnbPoolBorrow, 0, "unexpected bnb pool borrow");
    }

    function testGetMarketPauseStatusesDeprecatedMarket() public {
        evoq.setIsBorrowPaused(vDai, true);
        evoq.setIsDeprecated(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isDeprecated);
    }

    function testGetMarketPauseStatusesPauseSupply() public {
        evoq.setIsSupplyPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isSupplyPaused);
    }

    function testGetMarketPauseStatusesPauseBorrow() public {
        evoq.setIsBorrowPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isBorrowPaused);
    }

    function testGetMarketPauseStatusesPauseWithdraw() public {
        evoq.setIsWithdrawPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isWithdrawPaused);
    }

    function testGetMarketPauseStatusesPauseRepay() public {
        evoq.setIsRepayPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isRepayPaused);
    }

    function testGetMarketPauseStatusesPauseLiquidateOnCollateral() public {
        evoq.setIsLiquidateCollateralPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isLiquidateCollateralPaused);
    }

    function testGetMarketPauseStatusesPauseLiquidateOnBorrow() public {
        evoq.setIsLiquidateBorrowPaused(vDai, true);
        assertTrue(lens.getMarketPauseStatus(vDai).isLiquidateBorrowPaused);
    }

    function testPoolIndexGrowthInsideBlock() public {
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, 1 ether);

        uint256 poolBorrowIndexBefore = lens.getIndexes(vDai, true).poolSupplyIndex;

        vm.prank(address(supplier1));
        ERC20(dai).transfer(vDai, 10_000 ether);

        supplier1.supply(vDai, 1);

        uint256 poolSupplyIndexAfter = lens.getIndexes(vDai, true).poolSupplyIndex;

        assertGt(poolSupplyIndexAfter, poolBorrowIndexBefore);
    }

    function testP2PIndexGrowthInsideBlock() public {
        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, 1 ether);
        borrower1.borrow(vDai, 0.5 ether);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        // Bypass the borrow repay in the same block by overwritting the storage slot lastBorrowBlock[borrower1].
        hevm.store(address(evoq), keccak256(abi.encode(address(borrower1), 29)), 0);
        // Create delta.
        borrower1.repay(vDai, type(uint256).max);

        uint256 p2pSupplyIndexBefore = lens.getCurrentP2PSupplyIndex(vDai);

        vm.prank(address(supplier1));
        ERC20(dai).transfer(vDai, 10_000 ether);

        uint256 p2pSupplyIndexAfter = lens.getCurrentP2PSupplyIndex(vDai);

        assertGt(p2pSupplyIndexAfter, p2pSupplyIndexBefore);
    }
}
