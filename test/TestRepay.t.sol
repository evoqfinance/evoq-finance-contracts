// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestRepay is TestSetup {
    using CompoundMath for uint256;

    // The borrower repays no more than his `onPool` balance. The liquidity is repaid on his `onPool` balance.
    function testRepay1() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        moveOneBlockForwardBorrowRepay();

        borrower1.approve(dai, amount);
        borrower1.repay(vDai, amount);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertEq(inP2P, 0);
        testEqualityLarge(onPool, 0);
    }

    function testRepayAll() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        moveOneBlockForwardBorrowRepay();

        uint256 balanceBefore = borrower1.balanceOf(dai);
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        uint256 balanceAfter = supplier1.balanceOf(dai);

        assertEq(inP2P, 0);
        assertEq(onPool, 0);
        testEquality(balanceBefore - balanceAfter, amount);
    }

    // There is a borrower `onPool` available to replace him `inP2P`. First, his debt `onPool` is repaid, his matched debt is replaced by the available borrower up to his repaid amount.
    function testRepay2_1() public {
        uint256 suppliedAmount = 10000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for suppliedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(onPoolSupplier, 0, "supplier on pool");
        assertEq(inP2PSupplier, suppliedAmount.div(evoq.p2pSupplyIndex(vDai)), "supplier in peer-to-peer");
        assertEq(onPoolBorrower1, suppliedAmount.div(IVToken(vDai).borrowIndex()), "borrower on pool");
        assertEq(inP2PBorrower1, suppliedAmount.div(evoq.p2pBorrowIndex(vDai)), "borrower in peer-to-peer");

        // An available borrower onPool.
        uint256 availableBorrowerAmount = borrowedAmount / 4;
        borrower2.approve(usdc, (collateral));
        borrower2.supply(vUsdc, (collateral));
        borrower2.borrow(vDai, availableBorrowerAmount);

        moveOneBlockForwardBorrowRepay();

        // Borrower1 repays 75% of suppliedAmount.
        borrower1.approve(dai, (75 * borrowedAmount) / 100);
        borrower1.repay(vDai, (75 * borrowedAmount) / 100);

        // Check balances for borrower1 & borrower2.
        (inP2PBorrower1, onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PAvailableBorrower, uint256 onPoolAvailableBorrower) =
            evoq.borrowBalanceInOf(vDai, address(borrower2));
        uint256 expectedBorrowBalanceInP2P = ((25 * borrowedAmount) / 100).div(evoq.p2pBorrowIndex(vDai));

        testEqualityLarge(inP2PBorrower1, inP2PAvailableBorrower, "available in P2P");
        testEqualityLarge(inP2PBorrower1, expectedBorrowBalanceInP2P, "borrower in P2P 2");
        assertApproxEqAbs(onPoolAvailableBorrower, 0, 1e16, "available on pool");
        assertEq(onPoolBorrower1, 0, "borrower on pool 2");

        // Check balances for supplier.
        uint256 expectedInP2P = suppliedAmount.div(evoq.p2pSupplyIndex(vDai));
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        testEqualityLarge(inP2PSupplier, expectedInP2P, "supplier in P2P 2");
        assertEq(onPoolSupplier, 0, "supplier on pool 2");
    }

    // There are NMAX (or less) borrowers `onPool` available to replace him `inP2P`, they borrow enough to cover for the repaid liquidity. First, his debt `onPool` is repaid, his matched liquidity is replaced by NMAX (or less) borrowers up to his repaid amount.
    function testRepay2_2() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched up to suppliedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(onPoolSupplier, 0);
        testEqualityLarge(inP2PSupplier, suppliedAmount.div(evoq.p2pSupplyIndex(vDai)), "supplier in peer-to-peer");
        testEqualityLarge(onPoolBorrower1, suppliedAmount.div(IVToken(vDai).borrowIndex()), "borrower on pool");
        testEqualityLarge(inP2PBorrower1, suppliedAmount.div(evoq.p2pBorrowIndex(vDai)), "borrower in peer-to-peer");

        // NMAX borrowers have debt waiting on pool.
        uint256 NMAX = 20;
        createSigners(NMAX);

        Types.BorrowBalance memory vars;
        uint256 borrowIndex = IVToken(vDai).borrowIndex();

        // minus because borrower1 must not be counted twice !
        uint256 amountPerBorrower = (borrowedAmount - suppliedAmount) / (NMAX - 1);
        uint256 expectedOnPool;

        for (uint256 i = 0; i < NMAX; i++) {
            if (borrowers[i] == borrower1) continue;

            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));
            borrowers[i].borrow(vDai, amountPerBorrower);

            (vars.inP2P, vars.onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            expectedOnPool = amountPerBorrower.div(borrowIndex);

            assertEq(vars.inP2P, 0);
            assertEq(vars.onPool, expectedOnPool);
        }

        moveOneBlockForwardBorrowRepay();

        // Borrower1 repays all of his debt.
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        // His balance should be set to 0.
        (inP2PBorrower1, onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertEq(onPoolBorrower1, 0);
        assertEq(inP2PBorrower1, 0);

        // Check balances for the supplier.
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedSupplyBalanceInP2P = suppliedAmount.div(evoq.p2pSupplyIndex(vDai));

        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in peer-to-peer");
        assertEq(onPoolSupplier, 0, "supplier on pool");

        // Now test for each individual borrower that replaced the original.
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower1) continue;

            (vars.inP2P, vars.onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            uint256 expectedInP2P = expectedOnPool.mul(IVToken(vDai).borrowIndex()).div(evoq.p2pBorrowIndex(vDai));

            testEqualityLarge(vars.inP2P, expectedInP2P, "borrower in peer-to-peer");
            testEqualityLarge(vars.onPool, 0, "borrower on pool");
        }
    }

    // There are no borrowers `onPool` to replace him `inP2P`. After repaying the amount `onPool`, his P2P credit line will be broken and the corresponding supplier(s) will be unmatched, and placed on pool.
    function testRepay2_3() public {
        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for supplierAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        assertEq(onPoolSupplier, 0);
        assertEq(inP2PSupplier, suppliedAmount.div(evoq.p2pSupplyIndex(vDai)), "supplier in peer-to-peer");
        assertEq(onPoolBorrower1, suppliedAmount.div(IVToken(vDai).borrowIndex()), "borrower on pool");
        assertEq(inP2PBorrower1, suppliedAmount.div(evoq.p2pBorrowIndex(vDai)), "borrower in peer-to-peer");

        moveOneBlockForwardBorrowRepay();

        // Borrower1 repays 75% of borrowed amount.
        borrower1.approve(dai, (75 * borrowedAmount) / 100);
        borrower1.repay(vDai, (75 * borrowedAmount) / 100);

        // Check balances for borrower.
        (inP2PBorrower1, onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = ((25 * borrowedAmount) / 100).div(evoq.p2pBorrowIndex(vDai));

        testEqualityLarge(inP2PBorrower1, expectedBorrowBalanceInP2P, "borrower in P2P");
        assertEq(onPoolBorrower1, 0);

        // Check balances for supplier.
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedSupplyBalanceInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));
        uint256 expectedSupplyBalanceOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());

        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in P2P 2");
        testEqualityLarge(onPoolSupplier, expectedSupplyBalanceOnPool, "supplier on pool 2");
    }

    // The borrower is matched to 2 x NMAX suppliers. There are NMAX borrowers `onPool` available to replace him `inP2P`, they don't supply enough to cover for the repaid liquidity. First, the `onPool` liquidity is repaid, then we proceed to NMAX `match borrower`. Finally, we proceed to NMAX `unmatch supplier` for an amount equal to the remaining to withdraw.
    function testRepay2_4() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for suppliedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        testEqualityLarge(onPoolSupplier, 0);
        testEqualityLarge(inP2PSupplier, suppliedAmount.div(evoq.p2pSupplyIndex(vDai)), "supplier in peer-to-peer");
        assertEq(onPoolBorrower1, suppliedAmount.div(IVToken(vDai).borrowIndex()), "borrower on pool");
        assertEq(inP2PBorrower1, suppliedAmount.div(evoq.p2pBorrowIndex(vDai)), "borrower in peer-to-peer");

        // NMAX borrowers have borrowerAmount/2 (cumulated) of debt waiting on pool.
        uint256 NMAX = 20;
        createSigners(NMAX);

        // minus because borrower1 must not be counted twice !
        uint256 amountPerBorrower = (borrowedAmount - suppliedAmount) / (2 * (NMAX - 1));

        for (uint256 i = 0; i < NMAX; i++) {
            if (borrowers[i] == borrower1) continue;

            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));
            borrowers[i].borrow(vDai, amountPerBorrower);
        }

        moveOneBlockForwardBorrowRepay();

        // Borrower1 repays all of his debt.
        borrower1.approve(dai, borrowedAmount);
        borrower1.repay(vDai, borrowedAmount);

        // Borrower1 balance should be set to 0.
        (inP2PBorrower1, onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertEq(onPoolBorrower1, 0);
        testEqualityLarge(inP2PBorrower1, 0);

        // Check balances for the supplier.
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedSupplyBalanceOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedSupplyBalanceInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));

        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in peer-to-peer");
        testEqualityLarge(onPoolSupplier, expectedSupplyBalanceOnPool, "supplier on pool");

        uint256 inP2P;
        uint256 onPool;

        // Now test for each individual borrower that replaced the original
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower1) continue;

            (inP2P, onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));

            testEqualityLarge(inP2P, amountPerBorrower.div(evoq.p2pBorrowIndex(vDai)), "borrower in peer-to-peer");
            assertEq(onPool, 0, "borrower on pool");
        }
    }

    struct Vars {
        uint256 LR; // Loan Rate
        uint256 SPI; // Supply Index
        uint256 BPY; // Rate Per Block
        uint256 VBR; // Variable Borrow Rate
        uint256 SP2PD; // Supply P2P Delta
        uint256 SP2PA; // Supply P2P Amount
        uint256 SP2PER; // Supply P2P Percentage
    }

    function testDeltaRepay() public {
        // Allows only 10 unmatch suppliers.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 3e6, 0.9e6);

        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = 20 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        uint256 expectedBorrowBalanceInP2P;

        // borrower1 and 100 suppliers are matched for borrowedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        createSigners(30);
        uint256 matched;

        // 2 * NMAX suppliers supply suppliedAmount.
        for (uint256 i = 0; i < 20; i++) {
            suppliers[i].approve(dai, suppliedAmount);
            suppliers[i].supply(vDai, suppliedAmount);
            matched += suppliedAmount.div(evoq.p2pSupplyIndex(vDai));
        }

        {
            uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);
            expectedBorrowBalanceInP2P = borrowedAmount.div(p2pBorrowIndex);

            // Check balances after match of supplier1
            (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));
            assertApproxEqAbs(onPoolBorrower, 0, 20, "borrower on pool");
            testEqualityLarge(inP2PBorrower, expectedBorrowBalanceInP2P, "borrower in peer-to-peer");

            uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);
            uint256 expectedSupplyBalanceInP2P = suppliedAmount.div(p2pSupplyIndex);

            for (uint256 i = 0; i < 20; i++) {
                (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
                testEqualityLarge(onPoolSupplier, 0, "supplier on pool 1");
                testEquality(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in peer-to-peer 1");
            }

            moveOneBlockForwardBorrowRepay();

            // Borrower repays max.
            // Should create a delta on suppliers side.
            borrower1.approve(dai, type(uint256).max);
            borrower1.repay(vDai, type(uint256).max);

            {
                // Check balances for borrower1.
                (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.supplyBalanceInOf(vDai, address(borrower1));

                assertEq(onPoolBorrower1, 0);
                assertEq(inP2PBorrower1, 0);
            }

            // There should be a delta.
            // The amount unmatched during the repay.
            uint256 unmatched = 10 * expectedSupplyBalanceInP2P.mul(evoq.p2pSupplyIndex(vDai));
            // The difference between the previous matched amount and the amount unmatched creates a delta.
            uint256 expectedp2pSupplyDeltaInUnderlying = (matched.mul(evoq.p2pSupplyIndex(vDai)) - unmatched);
            uint256 expectedp2pSupplyDelta =
                (matched.mul(evoq.p2pSupplyIndex(vDai)) - unmatched).div(IVToken(vDai).exchangeRateCurrent());

            (uint256 p2pSupplyDelta,,,) = evoq.deltas(vDai);
            assertApproxEqAbs(p2pSupplyDelta, expectedp2pSupplyDelta, 10, "supply delta 1");

            // Supply delta matching by a new borrower.
            borrower2.approve(usdc, (collateral));
            borrower2.supply(vUsdc, (collateral));
            borrower2.borrow(vDai, expectedp2pSupplyDeltaInUnderlying / 2);

            (inP2PBorrower, onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower2));
            expectedBorrowBalanceInP2P = (expectedp2pSupplyDeltaInUnderlying / 2).div(p2pBorrowIndex);

            (p2pSupplyDelta,,,) = evoq.deltas(vDai);
            assertApproxEqAbs(p2pSupplyDelta, expectedp2pSupplyDelta / 2, 10, "supply delta unexpected");
            assertEq(onPoolBorrower, 0, "on pool unexpected");
            assertApproxEqAbs(inP2PBorrower, expectedBorrowBalanceInP2P, 1e3, "in peer-to-peer unexpected");
        }

        {
            Vars memory oldVars;
            Vars memory newVars;

            (oldVars.SP2PD,, oldVars.SP2PA,) = evoq.deltas(vDai);
            oldVars.SPI = IVToken(vDai).exchangeRateCurrent();
            oldVars.SP2PER = evoq.p2pSupplyIndex(vDai);
            (oldVars.BPY,) = getApproxP2PRates(vDai);

            move100BlocksForward(vDai);

            evoq.updateP2PIndexes(vDai);

            (newVars.SP2PD,, newVars.SP2PA,) = evoq.deltas(vDai);
            newVars.SPI = IVToken(vDai).exchangeRateCurrent();
            newVars.SP2PER = evoq.p2pSupplyIndex(vDai);
            newVars.LR = IVToken(vDai).supplyRatePerBlock();
            newVars.VBR = IVToken(vDai).borrowRatePerBlock();

            uint256 shareOfTheDelta = newVars.SP2PD.mul(newVars.SPI).div(oldVars.SP2PER).div(newVars.SP2PA);

            uint256 expectedSP2PER = oldVars.SP2PER.mul(
                _computeCompoundedInterest(oldVars.BPY, 1_000).mul(WAD - shareOfTheDelta)
                    + shareOfTheDelta.mul(newVars.SPI).div(oldVars.SPI)
            );

            assertApproxEqAbs(expectedSP2PER, newVars.SP2PER, (expectedSP2PER * 2) / 100, "SP2PER not expected");

            uint256 expectedSupplyBalanceInUnderlying = suppliedAmount.div(oldVars.SP2PER).mul(expectedSP2PER);

            for (uint256 i = 10; i < 20; i++) {
                (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));

                assertApproxEqAbs(
                    inP2PSupplier.mul(newVars.SP2PER),
                    expectedSupplyBalanceInUnderlying,
                    (expectedSupplyBalanceInUnderlying * 2) / 100,
                    "supplier in peer-to-peer 2"
                );
                assertEq(onPoolSupplier, 0, "supplier on pool 2");
            }
        }

        // Supply delta reduction with suppliers withdrawing
        for (uint256 i = 10; i < 20; i++) {
            suppliers[i].withdraw(vDai, suppliedAmount);
        }

        (uint256 p2pSupplyDeltaAfter,,,) = evoq.deltas(vDai);
        testEquality(p2pSupplyDeltaAfter, 0, "supply delta after");

        (uint256 inP2PBorrower2, uint256 onPoolBorrower2) = evoq.borrowBalanceInOf(vDai, address(borrower2));

        assertApproxEqAbs(inP2PBorrower2, expectedBorrowBalanceInP2P, 1e3, "borrower2 in peer-to-peer");
        assertEq(onPoolBorrower2, 0, "borrower2 on pool");
    }

    function testDeltaRepayAll() public {
        // Allows only 10 unmatch suppliers.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 3e6, 0.9e6);

        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = 20 * suppliedAmount + 1e12;
        uint256 collateral = 2 * borrowedAmount;

        // borrower1 and 100 suppliers are matched for borrowedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        createSigners(30);

        // 2 * NMAX suppliers supply suppliedAmount.
        for (uint256 i = 0; i < 20; i++) {
            suppliers[i].approve(dai, suppliedAmount + i);
            suppliers[i].supply(vDai, suppliedAmount + i);
        }

        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            assertEq(inP2P, (suppliedAmount + i).div(evoq.p2pSupplyIndex(vDai)), "inP2P");
            assertEq(onPool, 0, "onPool");
        }

        moveOneBlockForwardBorrowRepay();

        // Borrower repays max.
        // Should create a delta on suppliers side.
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        for (uint256 i = 0; i < 10; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            assertEq(inP2P, 0, string.concat("inP2P", Strings.toString(i)));
            assertApproxEqAbs(
                onPool,
                (suppliedAmount + i).div(IVToken(vDai).exchangeRateCurrent()),
                2 * 1e2,
                string.concat("onPool", Strings.toString(i))
            );
        }
        for (uint256 i = 10; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            assertApproxEqAbs(
                inP2P,
                (suppliedAmount + i).div(evoq.p2pSupplyIndex(vDai)),
                1e4,
                string.concat("inP2P", Strings.toString(i))
            );
            assertEq(onPool, 0, string.concat("onPool", Strings.toString(i)));
        }

        (uint256 p2pSupplyDelta, uint256 p2pBorrowDelta, uint256 p2pSupplyAmount, uint256 p2pBorrowAmount) =
            evoq.deltas(vDai);

        assertApproxEqAbs(
            p2pSupplyDelta, (10 * suppliedAmount).div(IVToken(vDai).exchangeRateCurrent()), 1e6, "p2pSupplyDelta"
        );
        assertEq(p2pBorrowDelta, 0, "p2pBorrowDelta");
        assertApproxEqAbs(
            p2pSupplyAmount, (10 * suppliedAmount).div(evoq.p2pSupplyIndex(vDai)), 2 * 1e3, "p2pSupplyAmount"
        );
        assertApproxEqAbs(p2pBorrowAmount, 0, 1, "p2pBorrowAmount");

        move100BlocksForward(vDai);

        for (uint256 i; i < 20; i++) {
            suppliers[i].withdraw(vDai, type(uint256).max);
        }

        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            assertEq(inP2P, 0, "inP2P");
            assertEq(onPool, 0, "onPool");
        }
    }

    function testFailRepayZero() public {
        evoq.repay(vDai, msg.sender, 0);
    }

    function testRepayRepayOnBehalf() public {
        uint256 amount = 1 ether;
        borrower1.approve(usdc, (2 * amount));
        borrower1.supply(vUsdc, (2 * amount));
        borrower1.borrow(vDai, amount);

        moveOneBlockForwardBorrowRepay();

        // Someone repays on behalf of the evoq.
        supplier2.approve(dai, vDai, amount);
        hevm.prank(address(supplier2));
        IVToken(vDai).repayBorrowBehalf(address(evoq), amount);

        // Borrower1 repays on pool. Not supposed to revert.
        borrower1.approve(dai, amount);
        borrower1.repay(vDai, amount);
    }

    function testRepayOnPoolThreshold() public {
        uint256 amountRepaid = 1e12;

        borrower1.approve(usdc, (2 ether));
        borrower1.supply(vUsdc, (2 ether));

        borrower1.borrow(vDai, 1 ether);

        uint256 onCompBeforeRepay = IVToken(vDai).borrowBalanceCurrent(address(evoq));
        (, uint256 onPoolBeforeRepay) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        moveOneBlockForwardBorrowRepay();

        // We check that repaying a dust quantity leads to a diminishing debt in both vToken & on Evoq.
        borrower1.approve(dai, amountRepaid);
        borrower1.repay(vDai, amountRepaid);

        uint256 onCompAfterRepay = IVToken(vDai).borrowBalanceCurrent(address(evoq));
        (, uint256 onPoolAfterRepay) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        assertLt(onCompAfterRepay, onCompBeforeRepay, "on Comp");
        assertLt(onPoolAfterRepay, onPoolBeforeRepay, "on Evoq");
    }

    function testRepayOnBehalf() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        moveOneBlockForwardBorrowRepay();

        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        evoq.repay(vDai, address(borrower1), amount);

        (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        testEqualityLarge(inP2P, 0);
        testEqualityLarge(onPool, 0);
    }

    function testCannotBorrowRepayInSameBlock() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        borrower1.approve(dai, amount);
        hevm.prank(address(borrower1));
        hevm.expectRevert(abi.encodeWithSignature("SameBlockBorrowRepay()"));
        evoq.repay(vDai, address(borrower1), amount);
    }

    function testCannotBorrowRepayOnBehalfInSameBlock() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, amount);

        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        hevm.expectRevert(abi.encodeWithSignature("SameBlockBorrowRepay()"));
        evoq.repay(vDai, address(borrower1), amount);
    }

    struct StackP2PVars {
        uint256 daiP2PSupplyIndexBefore;
        uint256 daiP2PBorrowIndexBefore;
        uint256 usdcP2PSupplyIndexBefore;
        uint256 usdcP2PBorrowIndexBefore;
        uint256 btcbP2PSupplyIndexBefore;
        uint256 btcbP2PBorrowIndexBefore;
        uint256 usdtP2PSupplyIndexBefore;
        uint256 usdtP2PBorrowIndexBefore;
    }

    struct StackPoolVars {
        uint256 daiPoolSupplyIndexBefore;
        uint256 daiPoolBorrowIndexBefore;
        uint256 usdcPoolSupplyIndexBefore;
        uint256 usdcPoolBorrowIndexBefore;
        uint256 btcbPoolSupplyIndexBefore;
        uint256 btcbPoolBorrowIndexBefore;
        uint256 usdtPoolSupplyIndexBefore;
        uint256 usdtPoolBorrowIndexBefore;
    }

    function testRepayUpdateIndexesSameAsVenus() public {
        uint256 collateral = 1 ether;
        uint256 borrow = collateral / 10;

        createMarket(vCake);

        {
            supplier1.approve(dai, type(uint256).max);
            supplier1.approve(usdc, type(uint256).max);
            supplier1.approve(usdt, type(uint256).max);

            supplier1.supply(vDai, collateral);
            supplier1.supply(vUsdc, (collateral));

            supplier1.borrow(vCake, borrow);
            supplier1.borrow(vUsdt, (borrow));

            StackP2PVars memory vars;

            vars.daiP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vDai);
            vars.daiP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vDai);
            vars.usdcP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vUsdc);
            vars.usdcP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vUsdc);
            vars.btcbP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vCake);
            vars.btcbP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vCake);
            vars.usdtP2PSupplyIndexBefore = evoq.p2pSupplyIndex(vUsdt);
            vars.usdtP2PBorrowIndexBefore = evoq.p2pBorrowIndex(vUsdt);

            hevm.roll(block.number + 1);

            supplier1.repay(vUsdt, (borrow));

            uint256 daiP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vDai);
            uint256 daiP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vDai);
            uint256 usdcP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vUsdc);
            uint256 usdcP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vUsdc);
            uint256 btcbP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vCake);
            uint256 btcbP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vCake);
            uint256 usdtP2PSupplyIndexAfter = evoq.p2pSupplyIndex(vUsdt);
            uint256 usdtP2PBorrowIndexAfter = evoq.p2pBorrowIndex(vUsdt);

            assertEq(daiP2PBorrowIndexAfter, vars.daiP2PSupplyIndexBefore);
            assertEq(daiP2PSupplyIndexAfter, vars.daiP2PBorrowIndexBefore);
            assertEq(usdcP2PSupplyIndexAfter, vars.usdcP2PSupplyIndexBefore);
            assertEq(usdcP2PBorrowIndexAfter, vars.usdcP2PBorrowIndexBefore);
            assertEq(btcbP2PSupplyIndexAfter, vars.btcbP2PSupplyIndexBefore);
            assertEq(btcbP2PBorrowIndexAfter, vars.btcbP2PBorrowIndexBefore);
            assertGt(usdtP2PSupplyIndexAfter, vars.usdtP2PSupplyIndexBefore);
            assertGt(usdtP2PBorrowIndexAfter, vars.usdtP2PBorrowIndexBefore);
        }

        {
            supplier1.venusSupply(vDai, collateral);
            supplier1.venusSupply(vUsdc, (collateral));

            supplier1.venusBorrow(vCake, borrow);
            supplier1.venusBorrow(vUsdt, (borrow));

            StackPoolVars memory vars;

            vars.daiPoolSupplyIndexBefore = IVToken(vDai).exchangeRateStored();
            vars.daiPoolBorrowIndexBefore = IVToken(vDai).borrowIndex();
            vars.usdcPoolSupplyIndexBefore = IVToken(vUsdc).exchangeRateStored();
            vars.usdcPoolBorrowIndexBefore = IVToken(vUsdc).borrowIndex();
            vars.btcbPoolSupplyIndexBefore = IVToken(vCake).exchangeRateStored();
            vars.btcbPoolBorrowIndexBefore = IVToken(vCake).borrowIndex();
            vars.usdtPoolSupplyIndexBefore = IVToken(vUsdt).exchangeRateStored();
            vars.usdtPoolBorrowIndexBefore = IVToken(vUsdt).borrowIndex();

            hevm.roll(block.number + 1);

            supplier1.venusRepay(vUsdt, 1);

            uint256 daiPoolSupplyIndexAfter = IVToken(vDai).exchangeRateStored();
            uint256 daiPoolBorrowIndexAfter = IVToken(vDai).borrowIndex();
            uint256 usdcPoolSupplyIndexAfter = IVToken(vUsdc).exchangeRateStored();
            uint256 usdcPoolBorrowIndexAfter = IVToken(vUsdc).borrowIndex();
            uint256 btcbPoolSupplyIndexAfter = IVToken(vCake).exchangeRateStored();
            uint256 btcbPoolBorrowIndexAfter = IVToken(vCake).borrowIndex();
            uint256 usdtPoolSupplyIndexAfter = IVToken(vUsdt).exchangeRateStored();
            uint256 usdtPoolBorrowIndexAfter = IVToken(vUsdt).borrowIndex();

            assertEq(daiPoolSupplyIndexAfter, vars.daiPoolSupplyIndexBefore);
            assertEq(daiPoolBorrowIndexAfter, vars.daiPoolBorrowIndexBefore);
            assertEq(usdcPoolSupplyIndexAfter, vars.usdcPoolSupplyIndexBefore);
            assertEq(usdcPoolBorrowIndexAfter, vars.usdcPoolBorrowIndexBefore);
            assertEq(btcbPoolSupplyIndexAfter, vars.btcbPoolSupplyIndexBefore);
            assertEq(btcbPoolBorrowIndexAfter, vars.btcbPoolBorrowIndexBefore);
            assertGt(usdtPoolSupplyIndexAfter, vars.usdtPoolSupplyIndexBefore);
            assertGt(usdtPoolBorrowIndexAfter, vars.usdtPoolBorrowIndexBefore);
        }
    }

    function testRepayWithMaxP2PSupplyDelta() public {
        uint256 supplyAmount = 1_000 ether;
        uint256 borrowAmount = 50 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, supplyAmount);
        supplier1.borrow(vDai, borrowAmount);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        supplier1.withdraw(vDai, borrowAmount); // Creates a 100% peer-to-peer borrow delta.

        hevm.roll(block.number + 1);

        supplier1.repay(vDai, type(uint256).max);
    }
}
