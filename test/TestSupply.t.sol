// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestSupply is TestSetup {
    using CompoundMath for uint256;

    // There are no available borrowers: all of the supplied amount is supplied to the pool and set `onPool`.
    function testSupply1() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        testEquality(ERC20(vDai).balanceOf(address(evoq)), expectedOnPool, "balance of vToken");

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        testEquality(onPool, expectedOnPool, "on pool");
        assertEq(inP2P, 0, "in peer-to-peer");
    }

    // There is 1 available borrower, he matches 100% of the supplier liquidity, everything is `inP2P`.
    function testSupply2() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        uint256 daiBalanceBefore = supplier1.balanceOf(dai);
        uint256 expectedDaiBalanceAfter = daiBalanceBefore - amount;

        supplier1.approve(dai, address(evoq), amount);
        supplier1.supply(vDai, amount);

        uint256 daiBalanceAfter = supplier1.balanceOf(dai);
        testEquality(daiBalanceAfter, expectedDaiBalanceAfter);

        uint256 expectedSupplyBalanceInP2P = amount.div(evoq.p2pSupplyIndex(vDai));
        uint256 expectedBorrowBalanceInP2P = amount.div(evoq.p2pBorrowIndex(vDai));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertEq(onPoolSupplier, 0, "supplier on pool");
        assertEq(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in P2P");

        assertEq(onPoolBorrower, 0, "borrower on pool");
        assertEq(inP2PBorrower, expectedBorrowBalanceInP2P, "borrower in P2P");
    }

    // There is 1 available borrower, he doesn't match 100% of the supplier liquidity. Supplier's balance `inP2P` is equal to the borrower previous amount `onPool`, the rest is set `onPool`.
    function testSupply3() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, 2 * amount);
        supplier1.supply(vDai, 2 * amount);

        uint256 expectedSupplyBalanceInP2P = amount.div(evoq.p2pSupplyIndex(vDai));
        uint256 expectedSupplyBalanceOnPool = amount.div(IVToken(vDai).exchangeRateCurrent());

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        testEquality(onPoolSupplier, expectedSupplyBalanceOnPool, "on pool supplier");
        testEquality(inP2PSupplier, expectedSupplyBalanceInP2P, "in peer-to-peer supplier");

        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        uint256 expectedInP2P = amount.div(evoq.p2pBorrowIndex(vDai));

        assertEq(onPoolBorrower, 0, "on pool borrower");
        assertEq(inP2PBorrower, expectedInP2P, "in peer-to-peer borrower");
    }

    // There are NMAX (or less) borrowers that match the supplied amount, everything is `inP2P` after NMAX (or less) match.
    function testSupply4() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 amount = 10000 ether;
        uint256 collateral = 2 * amount;

        uint256 NMAX = 20;
        createSigners(NMAX);

        uint256 amountPerBorrower = amount / NMAX;

        for (uint256 i = 0; i < NMAX; i++) {
            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));

            borrowers[i].borrow(vDai, amountPerBorrower);
        }

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        uint256 inP2P;
        uint256 onPool;
        uint256 expectedInP2P;
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);

        for (uint256 i = 0; i < NMAX; i++) {
            (inP2P, onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));

            expectedInP2P = amountPerBorrower.div(evoq.p2pBorrowIndex(vDai));

            testEquality(inP2P, expectedInP2P, "amount per borrower");
            assertEq(onPool, 0, "on pool per borrower");
        }

        (inP2P, onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        expectedInP2P = amount.div(p2pSupplyIndex);

        testEquality(inP2P, expectedInP2P, "in peer-to-peer");
        assertEq(onPool, 0, "on pool");
    }

    // The NMAX biggest borrowers don't match all of the supplied amount, after NMAX match, the rest is supplied and set `onPool`. ⚠️ most gas expensive supply scenario.
    function testSupply5() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 amount = 10000 ether;
        uint256 collateral = 2 * amount;

        uint256 NMAX = 20;
        createSigners(NMAX);

        uint256 amountPerBorrower = amount / (2 * NMAX);

        for (uint256 i = 0; i < NMAX; i++) {
            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));

            borrowers[i].borrow(vDai, amountPerBorrower);
        }

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        uint256 inP2P;
        uint256 onPool;
        uint256 expectedInP2P;
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);
        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();

        for (uint256 i = 0; i < NMAX; i++) {
            (inP2P, onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));

            expectedInP2P = amountPerBorrower.div(evoq.p2pBorrowIndex(vDai));

            testEquality(inP2P, expectedInP2P, "borrower in peer-to-peer");
            assertEq(onPool, 0, "borrower on pool");
        }

        (inP2P, onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        expectedInP2P = (amount / 2).div(p2pSupplyIndex);
        uint256 expectedOnPool = (amount / 2).div(poolSupplyIndex);

        testEquality(inP2P, expectedInP2P, "in peer-to-peer");
        testEquality(onPool, expectedOnPool, "in pool");
    }

    function testSupplyMultipleTimes() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, 2 * amount);

        supplier1.supply(vDai, amount);
        supplier1.supply(vDai, amount);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 expectedOnPool = (2 * amount).div(poolSupplyIndex);

        (, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        testEquality(onPool, expectedOnPool);
    }

    function testShouldNotSupplyZero() public {
        hevm.expectRevert(PositionsManager.AmountIsZero.selector);
        evoq.supply(vDai, msg.sender, 0, type(uint256).max);
    }

    function testSupplyRepayOnBehalf() public {
        uint256 amount = 1 ether;
        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        // Someone repays on behalf of the evoq.
        supplier2.approve(dai, vDai, amount);
        hevm.prank(address(supplier2));
        IVToken(vDai).repayBorrowBehalf(address(evoq), amount);

        // Supplier supplies in peer-to-peer. Not supposed to revert.
        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);
    }

    function testSupplyOnPoolThreshold() public {
        uint256 amountSupplied = 1e6;

        supplier1.approve(dai, amountSupplied);
        supplier1.supply(vDai, amountSupplied);

        // We check that supplying 0 in vToken units doesn't lead to a revert.
        (, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        assertEq(IVToken(vDai).balanceOf(address(positionsManager)), 0, "balance of vToken");
        assertEq(onPool, 0, "Balance in Positions Manager");
    }

    function testSupplyOnBehalf() public {
        uint256 amount = 10000 ether;

        supplier1.approve(dai, amount);
        hevm.prank(address(supplier1));
        evoq.supply(vDai, address(supplier2), amount);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 expectedOnPool = amount.div(poolSupplyIndex);

        assertEq(ERC20(vDai).balanceOf(address(evoq)), expectedOnPool, "balance of vToken");

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier2));

        assertEq(onPool, expectedOnPool, "on pool");
        assertEq(inP2P, 0, "in peer-to-peer");
    }

    function testSupplyUpdateIndexesSameAsVenus() public {
        uint256 amount = 1 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.approve(usdc, type(uint256).max);

        supplier1.supply(vDai, amount);
        supplier1.supply(vUsdc, (amount));

        uint256 daiP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vDai);
        uint256 daiP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vDai);
        uint256 usdcP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vUsdc);
        uint256 usdcP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vUsdc);

        hevm.roll(block.number + 1);

        supplier1.supply(vDai, amount);

        uint256 daiP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vDai);
        uint256 daiP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vDai);
        uint256 usdcP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vUsdc);
        uint256 usdcP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vUsdc);

        assertGt(daiP2PBorrowIndexAfter, daiP2PSupplyIndexBefore);
        assertGt(daiP2PSupplyIndexAfter, daiP2PBorrowIndexBefore);
        assertEq(usdcP2PSupplyIndexAfter, usdcP2PSupplyIndexBefore);
        assertEq(usdcP2PBorrowIndexAfter, usdcP2PBorrowIndexBefore);

        supplier1.venusSupply(vDai, amount);
        supplier1.venusSupply(vUsdc, (amount));

        uint256 daiPoolSupplyIndexBefore = IVToken(vDai).exchangeRateStored();
        uint256 daiPoolBorrowIndexBefore = IVToken(vDai).borrowIndex();
        uint256 usdcPoolSupplyIndexBefore = IVToken(vUsdc).exchangeRateStored();
        uint256 usdcPoolBorrowIndexBefore = IVToken(vUsdc).borrowIndex();

        hevm.roll(block.number + 1);

        supplier1.venusSupply(vDai, amount);

        uint256 daiPoolSupplyIndexAfter = IVToken(vDai).exchangeRateStored();
        uint256 daiPoolBorrowIndexAfter = IVToken(vDai).borrowIndex();
        uint256 usdcPoolSupplyIndexAfter = IVToken(vUsdc).exchangeRateStored();
        uint256 usdcPoolBorrowIndexAfter = IVToken(vUsdc).borrowIndex();

        assertGt(daiPoolSupplyIndexAfter, daiPoolSupplyIndexBefore);
        assertGt(daiPoolBorrowIndexAfter, daiPoolBorrowIndexBefore);
        assertEq(usdcPoolSupplyIndexAfter, usdcPoolSupplyIndexBefore);
        assertEq(usdcPoolBorrowIndexAfter, usdcPoolBorrowIndexBefore);
    }

    function testShouldMatchSupplyWithCorrectAmountOfGas() public {
        uint256 amount = 100 ether;
        createSigners(30);

        uint256 snapshotId = vm.snapshot();
        uint256 gasUsed1 = _getSupplyGasUsage(amount, 1e5); // small max gas => match only 1 borrower. matching engine gas used: 100,567

        vm.revertTo(snapshotId);
        uint256 gasUsed2 = _getSupplyGasUsage(amount, 2e5); // enough gas to match only 3 borrowers. matching engine gas used: 294,694

        assertGt(gasUsed2, gasUsed1 + 5e4);

        vm.revertTo(snapshotId);
        uint256 gasUsed3 = _getSupplyGasUsage(amount, 3e6); // enough gas to match all borrowers
        assertGt(gasUsed3, gasUsed2); // total gas used: 2,520,089. matching engine gas used: 2,108,335.
    }

    function testPoolIndexGrowthInsideBlock() public {
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, 1 ether);

        (, uint256 poolSupplyIndexCachedBefore,) = evoq.lastPoolIndexes(vDai);

        vm.prank(address(supplier1));
        ERC20(dai).transfer(vDai, 10_000 ether);

        supplier1.supply(vDai, 1);

        (, uint256 poolSupplyIndexCachedAfter,) = evoq.lastPoolIndexes(vDai);

        assertGt(poolSupplyIndexCachedAfter, poolSupplyIndexCachedBefore);
    }

    function testP2PIndexGrowthInsideBlock() public {
        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, 1 ether);
        borrower1.borrow(vDai, 0.5 ether);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);

        // Bypass the borrow repay in the same block by overwrittting the storage slot lastBorrowBlock[borrower1].
        hevm.store(address(evoq), keccak256(abi.encode(address(borrower1), 29)), 0);

        // Create delta.
        borrower1.repay(vDai, type(uint256).max);

        uint256 p2pSupplyIndexBefore = evoq.p2pSupplyIndex(vDai);

        vm.prank(address(supplier1));
        ERC20(dai).transfer(vDai, 10_000 ether);

        borrower1.supply(vDai, 1);

        uint256 p2pSupplyIndexAfter = evoq.p2pSupplyIndex(vDai);

        assertGt(p2pSupplyIndexAfter, p2pSupplyIndexBefore);
    }

    /// @dev Helper for gas usage test
    function _getSupplyGasUsage(uint256 amount, uint256 maxGas) internal returns (uint256 gasUsed) {
        // 2 * NMAX borrowers borrow amount
        for (uint256 i; i < 30; i++) {
            borrowers[i].approve(usdc, type(uint256).max);
            borrowers[i].supply(vUsdc, (amount * 3));
            borrowers[i].borrow(vDai, amount);
        }

        supplier1.approve(dai, amount * 20);

        uint256 gasLeftBefore = gasleft();
        supplier1.supply(vDai, amount * 20, maxGas);

        gasUsed = gasLeftBefore - gasleft();
    }
}
