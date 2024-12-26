// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestBorrow is TestSetup {
    using CompoundMath for uint256;

    // The borrower tries to borrow more than his collateral allows, the transaction reverts.
    function testBorrow1() public {
        uint256 usdcAmount = 10_000 ether;

        borrower1.approve(usdc, usdcAmount);
        borrower1.supply(vUsdc, usdcAmount);

        (, uint256 borrowable) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vUsdt);

        hevm.expectRevert(PositionsManager.UnauthorisedBorrow.selector);
        borrower1.borrow(vUsdt, borrowable + 1e12);
    }

    // There are no available suppliers: all of the borrowed amount is `onPool`.
    function testBorrow2() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, 2 * amount);
        borrower1.supply(vUsdc, 2 * amount);
        borrower1.borrow(vUsdt, amount);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedOnPool = amount.div(IVToken(vUsdt).borrowIndex());

        testEquality(onPool, expectedOnPool);
        assertEq(inP2P, 0);
    }

    // There is 1 available supplier, he matches 100% of the borrower liquidity, everything is `inP2P`.
    function testBorrow3() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(usdt, amount);
        supplier1.supply(vUsdt, amount);

        borrower1.approve(usdc, amount * 2);
        borrower1.supply(vUsdc, amount * 2);

        uint256 vUsdtSupplyIndex = IVToken(vUsdt).exchangeRateCurrent();
        (, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vUsdt, address(supplier1));
        uint256 toBorrow = supplyOnPool.mul(vUsdtSupplyIndex);
        borrower1.borrow(vUsdt, toBorrow);

        (uint256 supplyInP2P,) = evoq.supplyBalanceInOf(vUsdt, address(supplier1));

        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vUsdt);
        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vUsdt);
        uint256 expectedSupplyInP2P = getBalanceOnVenus(amount, vUsdtSupplyIndex).div(p2pSupplyIndex);
        uint256 expectedBorrowInP2P = getBalanceOnVenus(amount, vUsdtSupplyIndex).div(p2pBorrowIndex);

        testEquality(supplyInP2P, expectedSupplyInP2P, "Supplier1 in peer-to-peer");

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        assertEq(onPool, 0, "Borrower1 on pool");
        testEquality(inP2P, expectedBorrowInP2P, "Borrower1 in peer-to-peer");
    }

    // There is 1 available supplier, he doesn't match 100% of the borrower liquidity. Borrower `inP2P` is equal to the supplier previous amount `onPool`, the rest is set `onPool`.
    function testBorrow4() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(usdt, amount);
        supplier1.supply(vUsdt, amount);

        borrower1.approve(usdc, (4 * amount));
        borrower1.supply(vUsdc, (4 * amount));
        uint256 borrowAmount = amount * 2;

        uint256 vUsdtSupplyIndex = IVToken(vUsdt).exchangeRateCurrent();
        borrower1.borrow(vUsdt, borrowAmount);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedBorrowInP2P = getBalanceOnVenus(amount, vUsdtSupplyIndex).div(evoq.p2pBorrowIndex(vUsdt));
        uint256 expectedBorrowOnPool =
            (borrowAmount - getBalanceOnVenus(amount, vUsdtSupplyIndex)).div(IVToken(vUsdt).borrowIndex());

        testEquality(inP2P, expectedBorrowInP2P, "Borrower1 in peer-to-peer");
        testEquality(onPool, expectedBorrowOnPool, "Borrower1 on pool");
    }

    // There are NMAX (or less) supplier that match the borrowed amount, everything is `inP2P` after NMAX (or less) match.
    function testBorrow5() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        uint256 NMAX = 5;
        createSigners(NMAX);

        uint256 amountPerSupplier = amount / NMAX;
        uint256[] memory rates = new uint256[](NMAX);
        uint256 toBorrow;

        for (uint256 i = 0; i < NMAX; i++) {
            // Rates change every time.
            rates[i] = IVToken(vUsdt).exchangeRateCurrent();
            suppliers[i].approve(usdt, amountPerSupplier);
            suppliers[i].supply(vUsdt, amountPerSupplier);

            (, uint256 supplyOnPool) = evoq.supplyBalanceInOf(vUsdt, address(supplier1));
            toBorrow += supplyOnPool.mul(rates[i]);
        }

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));

        uint256 vUsdtSupplyIndex = IVToken(vUsdt).exchangeRateCurrent();
        borrower1.borrow(vUsdt, toBorrow);
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vUsdt);
        uint256 inP2P;
        uint256 onPool;

        for (uint256 i = 0; i < NMAX; i++) {
            (inP2P, onPool) = evoq.supplyBalanceInOf(vUsdt, address(suppliers[i]));

            testEquality(inP2P, getBalanceOnVenus(amountPerSupplier, rates[i]).div(p2pSupplyIndex), "in peer-to-peer");
            assertEq(onPool, 0, "on pool");
        }

        (inP2P, onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedBorrowInP2P = getBalanceOnVenus(amount, vUsdtSupplyIndex).div(evoq.p2pBorrowIndex(vUsdt));

        testEquality(inP2P, expectedBorrowInP2P, "Borrower1 in peer-to-peer");
        assertEq(onPool, 0);
    }

    // The NMAX biggest supplier don't match all of the borrowed amount, after NMAX match, the rest is borrowed and set `onPool`. ⚠️ most gas expensive borrow scenario.
    function testBorrow6() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 amount = 10000 ether;
        uint256 collateral = 2 * amount;

        uint256 NMAX = 5;
        createSigners(NMAX);

        uint256 amountPerSupplier = amount / (2 * NMAX);
        uint256[] memory rates = new uint256[](NMAX);

        for (uint256 i = 0; i < NMAX; i++) {
            // Rates change every time.
            rates[i] = IVToken(vUsdt).exchangeRateCurrent();
            suppliers[i].approve(usdt, amountPerSupplier);
            suppliers[i].supply(vUsdt, amountPerSupplier);
        }

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));

        uint256 vUsdtSupplyIndex = IVToken(vUsdt).exchangeRateCurrent();
        borrower1.borrow(vUsdt, amount);

        uint256 inP2P;
        uint256 onPool;
        uint256 borrowIndex = IVToken(vUsdt).borrowIndex();
        uint256 matchedAmount;

        for (uint256 i = 0; i < NMAX; i++) {
            (inP2P, onPool) = evoq.supplyBalanceInOf(vUsdt, address(suppliers[i]));

            testEquality(
                inP2P, getBalanceOnVenus(amountPerSupplier, rates[i]).div(evoq.p2pSupplyIndex(vUsdt)), "in peer-to-peer"
            );
            assertEq(onPool, 0, "on pool");

            matchedAmount += getBalanceOnVenus(amountPerSupplier, vUsdtSupplyIndex);
        }

        (inP2P, onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedBorrowInP2P = getBalanceOnVenus(amount / 2, vUsdtSupplyIndex).div(evoq.p2pBorrowIndex(vUsdt));
        uint256 expectedBorrowOnPool = (amount - matchedAmount).div(borrowIndex);

        testEquality(inP2P, expectedBorrowInP2P, "Borrower1 in peer-to-peer");
        testEquality(onPool, expectedBorrowOnPool, "Borrower1 on pool");
    }

    function testBorrowOnBehalf() public {
        uint256 amount = 1_000 ether;
        uint256 bnbAmount = 1 ether;

        supplier1.approve(usdt, 2 * amount);
        supplier1.supply(vUsdt, 2 * amount);

        // supplier1 has not approved wbnbgateway to be manager yet, but because delegator == manager, the borrow will succeed.
        supplier1.borrow(vUsdc, 10 ether, address(supplier1), address(supplier1));

        // supplier1 has not approved wbnbgateway to be manager yet.
        hevm.expectRevert(Evoq.PermissionDenied.selector);
        supplier1.borrowBNB(bnbAmount, address(supplier1));

        // borrower1 need to have some collateral, otherwise the borrow will revert because of insufficient collateral.
        borrower1.approve(usdc, 2 * amount);
        borrower1.supply(vUsdc, 2 * amount);

        // borrower1 (attacker) is not the manager of supplier1.
        hevm.expectRevert(Evoq.PermissionDenied.selector);
        borrower1.borrow(vUsdt, amount, address(supplier1), address(borrower1));

        // after approve manager, supplier1 can borrow BNB using wbnbGateway.
        supplier1.approveManager(address(wbnbGateway), true);
        supplier1.borrowBNB(bnbAmount, address(supplier1));
        (, uint256 onPool) = evoq.borrowBalanceInOf(vBnb, address(supplier1));
        uint256 expectedOnPool = bnbAmount.div(IVToken(vBnb).borrowIndex());

        testEquality(onPool, expectedOnPool, "Supplier1 on pool");
    }

    function testBorrowMultipleAssets() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, address(evoq), (4 * amount));
        borrower1.supply(vUsdc, (4 * amount));

        borrower1.borrow(vUsdt, amount);
        borrower1.borrow(vUsdt, amount);

        (, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        uint256 expectedOnPool = (2 * amount).div(IVToken(vUsdt).borrowIndex());
        testEquality(onPool, expectedOnPool);
    }

    function testShouldNotBorrowZero() public {
        hevm.expectRevert(PositionsManager.AmountIsZero.selector);
        evoq.borrow(vUsdt, 0);
    }

    function testBorrowOnPoolThreshold() public {
        uint256 amountBorrowed = 1;

        borrower1.approve(usdc, (1 ether));
        borrower1.supply(vUsdc, (1 ether));

        // We check that borrowing any amount accrue the debt.
        borrower1.borrow(vUsdt, amountBorrowed);
        (, uint256 onPool) = evoq.borrowBalanceInOf(vUsdt, address(borrower1));

        testEquality(onPool, IVToken(vUsdt).balanceOf(address(evoq)));
        testEquality(IVToken(vUsdt).borrowBalanceCurrent(address(evoq)), amountBorrowed, "borrow balance");
    }

    function testBorrowLargerThanDeltaShouldClearDelta() public {
        // Allows only 10 unmatch suppliers.

        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = 20 * suppliedAmount;
        uint256 collateral = 100 * borrowedAmount;

        // borrower1 and 20 suppliers are matched for borrowedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vUsdt, borrowedAmount);

        createSigners(20);

        // 2 * NMAX suppliers supply suppliedAmount.
        for (uint256 i = 0; i < 20; i++) {
            suppliers[i].approve(usdt, suppliedAmount);
            suppliers[i].supply(vUsdt, suppliedAmount);
        }

        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);

        vm.roll(block.number + 1);
        // Delta should be created.
        borrower1.approve(usdt, type(uint256).max);
        borrower1.repay(vUsdt, type(uint256).max);

        vm.roll(block.number + 1);
        (uint256 p2pSupplyDeltaBefore,,,) = evoq.deltas(vUsdt);
        borrower1.borrow(vUsdt, borrowedAmount * 2);
        (uint256 p2pSupplyDeltaAfter,,,) = evoq.deltas(vUsdt);

        assertGt(p2pSupplyDeltaBefore, 0);
        assertEq(p2pSupplyDeltaAfter, 0);
    }

    function testShouldMatchBorrowWithCorrectAmountOfGas() public {
        uint256 amount = 100 ether;
        createSigners(30);

        uint256 snapshotId = vm.snapshot();
        uint256 gasUsed1 = _getBorrowGasUsage(amount, 1e5);

        vm.revertTo(snapshotId);
        uint256 gasUsed2 = _getBorrowGasUsage(amount, 2e5);

        assertGt(gasUsed2, gasUsed1 + 5e4);
    }

    /// @dev Helper for gas usage test
    function _getBorrowGasUsage(uint256 amount, uint256 maxGas) internal returns (uint256 gasUsed) {
        // 2 * NMAX suppliers supply amount
        for (uint256 i; i < 30; i++) {
            suppliers[i].approve(usdt, type(uint256).max);
            suppliers[i].supply(vUsdt, amount);
        }

        borrower1.approve(usdc, (amount * 200));
        borrower1.supply(vUsdc, (amount * 200));

        uint256 gasLeftBefore = gasleft();
        borrower1.borrow(vUsdt, amount * 20, maxGas);

        gasUsed = gasLeftBefore - gasleft();
    }
}
