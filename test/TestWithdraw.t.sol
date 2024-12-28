// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Attacker} from "./helpers/Attacker.sol";
import "./setup/TestSetup.sol";

contract TestWithdraw is TestSetup {
    using CompoundMath for uint256;

    // The user withdrawal leads to an under-collateralized position, the withdrawal reverts.
    function testWithdraw1() public {
        uint256 amount = 10000 ether;
        uint256 collateral = 2 * amount;

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));

        borrower1.borrow(vDai, amount);

        hevm.expectRevert(abi.encodeWithSignature("UnauthorisedWithdraw()"));
        borrower1.withdraw(vUsdc, (collateral));
    }

    // The supplier withdraws less than his `onPool` balance. The liquidity is taken from his `onPool` balance.
    function testWithdraw2() public {
        uint256 amount = 10000 ether;

        supplier1.approve(usdc, (2 * amount));
        supplier1.supply(vUsdc, (2 * amount));

        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));

        uint256 expectedOnPool = (2 * amount).div(IVToken(vUsdc).exchangeRateCurrent());

        assertEq(inP2P, 0);
        testEquality(onPool, expectedOnPool);

        supplier1.withdraw(vUsdc, (amount));

        (inP2P, onPool) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));

        assertEq(inP2P, 0);
        testEquality(onPool, expectedOnPool / 2);
    }

    // The supplier withdraws all its `onPool` balance.
    function testWithdrawAll() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(usdc, (amount));
        supplier1.supply(vUsdc, (amount));

        uint256 balanceBefore = supplier1.balanceOf(usdc);
        (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));

        uint256 expectedOnPool = (amount).div(IVToken(vUsdc).exchangeRateCurrent());

        assertEq(inP2P, 0);
        testEquality(onPool, expectedOnPool);

        supplier1.withdraw(vUsdc, type(uint256).max);

        uint256 balanceAfter = supplier1.balanceOf(usdc);
        (inP2P, onPool) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));

        assertEq(inP2P, 0, "in peer-to-peer");
        assertEq(onPool, 0, "on Pool");
        assertApproxEqAbs(balanceAfter - balanceBefore, amount, 2 * 1e8, "balance");
    }

    // There is a supplier `onPool` available to replace him `inP2P`. First, his liquidity `onPool` is taken, his matched is replaced by the available supplier up to his withdrawal amount.
    function testWithdraw3_1() public {
        uint256 borrowedAmount = 10000 ether;
        uint256 suppliedAmount = 2 * borrowedAmount;
        uint256 collateral = 2 * borrowedAmount;

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        // Check balances after match of borrower1 & supplier1
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));

        testEquality(onPoolSupplier, expectedOnPool);
        assertEq(onPoolBorrower1, 0);
        assertEq(inP2PSupplier, expectedInP2P);

        // An available supplier onPool
        supplier2.approve(dai, suppliedAmount);
        supplier2.supply(vDai, suppliedAmount);

        // supplier withdraws suppliedAmount
        supplier1.withdraw(vDai, suppliedAmount);

        // Check balances for supplier1
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        assertEq(onPoolSupplier, 0);
        testEquality(inP2PSupplier, 0);

        // Check balances for supplier2
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier2));
        expectedInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));
        assertApproxEqAbs(onPoolSupplier, expectedOnPool, 2);
        assertApproxEqAbs(inP2PSupplier, expectedInP2P, 2);

        // Check balances for borrower1
        (inP2PBorrower1, onPoolBorrower1) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        expectedInP2P = (suppliedAmount / 2).div(evoq.p2pBorrowIndex(vDai));
        assertEq(onPoolBorrower1, 0);
        assertApproxEqAbs(inP2PBorrower1, expectedInP2P, 1);
    }

    // There are NMAX (or less) suppliers `onPool` available to replace him `inP2P`, they supply enough to cover for the withdrawn liquidity. First, his liquidity `onPool` is taken, his matched is replaced by NMAX (or less) suppliers up to his withdrawal amount.
    function testWithdraw3_2() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 borrowedAmount = 100_000 ether;
        uint256 suppliedAmount = 2 * borrowedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for suppliedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));

        testEquality(onPoolSupplier, expectedOnPool);
        assertEq(onPoolBorrower, 0);
        assertEq(inP2PSupplier, expectedInP2P);

        // NMAX-1 suppliers have up to suppliedAmount waiting on pool
        uint256 NMAX = 20;
        createSigners(NMAX);

        // minus 1 because supplier1 must not be counted twice !
        uint256 amountPerSupplier = (suppliedAmount - borrowedAmount) / (NMAX - 1);

        for (uint256 i = 0; i < NMAX; i++) {
            if (suppliers[i] == supplier1) continue;

            suppliers[i].approve(dai, amountPerSupplier);
            suppliers[i].supply(vDai, amountPerSupplier);
        }

        // supplier1 withdraws suppliedAmount.
        supplier1.withdraw(vDai, type(uint256).max);

        // Check balances for supplier1.
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        assertEq(onPoolSupplier, 0);
        testEquality(inP2PSupplier, 0);

        // Check balances for the borrower.
        (inP2PBorrower, onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = borrowedAmount.div(evoq.p2pBorrowIndex(vDai));

        testEquality(inP2PBorrower, expectedBorrowBalanceInP2P, "borrower in peer-to-peer");
        assertApproxEqAbs(onPoolBorrower, 0, 1e10, "borrower on Pool");

        // Now test for each individual supplier that replaced the original.
        for (uint256 i = 0; i < suppliers.length; i++) {
            if (suppliers[i] == supplier1) continue;

            (uint256 inP2P, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));
            expectedInP2P = amountPerSupplier.div(evoq.p2pSupplyIndex(vDai));

            testEquality(inP2P, expectedInP2P, "in peer-to-peer");
            assertEq(onPool, 0, "on pool");
        }
    }

    // There are no suppliers `onPool` to replace him `inP2P`. After withdrawing the amount `onPool`, his peer-to-peer credit lines will be broken and the corresponding borrower(s) will be unmatched and placed on pool.
    function testWithdraw3_3() public {
        uint256 borrowedAmount = 100 ether;
        uint256 suppliedAmount = 2 * borrowedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for borrowedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));

        testEquality(onPoolSupplier, expectedOnPool);
        assertEq(onPoolBorrower, 0);
        assertEq(inP2PSupplier, expectedInP2P);

        // Supplier1 withdraws 75% of supplied amount
        uint256 toWithdraw = (75 * suppliedAmount) / 100;
        supplier1.withdraw(vDai, toWithdraw);

        // Check balances for the borrower
        (inP2PBorrower, onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        uint256 expectedBorrowBalanceInP2P = (borrowedAmount / 2).div(evoq.p2pBorrowIndex(vDai));

        // The amount withdrawn from supplier1 minus what is on pool will be removed from the borrower peer-to-peer's position.
        uint256 expectedBorrowBalanceOnPool =
            (toWithdraw - onPoolSupplier.mul(IVToken(vDai).exchangeRateCurrent())).div(IVToken(vDai).borrowIndex());

        assertApproxEqAbs(inP2PBorrower, expectedBorrowBalanceInP2P, 1, "borrower in peer-to-peer");
        assertApproxEqAbs(onPoolBorrower, expectedBorrowBalanceOnPool, 1e4, "borrower on Pool");

        // Check balances for supplier
        (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedSupplyBalanceInP2P = ((25 * suppliedAmount) / 100).div(evoq.p2pSupplyIndex(vDai));

        assertApproxEqAbs(inP2PSupplier, expectedSupplyBalanceInP2P, 2, "supplier in peer-to-peer");
        assertEq(onPoolSupplier, 0, "supplier on Pool");
    }

    // The supplier is matched to 2 x NMAX borrowers. There are NMAX suppliers `onPool` available to replace him `inP2P`, they don't supply enough to cover the withdrawn liquidity. First, the `onPool` liquidity is withdrawn, then we proceed to NMAX `match supplier`. Finally, we proceed to NMAX `unmatch borrower` for an amount equal to the remaining to withdraw.
    function testWithdraw3_4() public {
        setDefaultMaxGasForMatchingHelper(type(uint64).max, type(uint64).max, type(uint64).max, type(uint64).max);

        uint256 borrowedAmount = 100 ether;
        uint256 suppliedAmount = 2 * borrowedAmount;
        uint256 collateral = 2 * borrowedAmount;

        // Borrower1 & supplier1 are matched for suppliedAmount.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));
        borrower1.borrow(vDai, borrowedAmount);

        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        // Check balances after match of borrower1 & supplier1.
        (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

        (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));

        uint256 expectedOnPool = (suppliedAmount / 2).div(IVToken(vDai).exchangeRateCurrent());
        uint256 expectedInP2P = (suppliedAmount / 2).div(evoq.p2pSupplyIndex(vDai));

        testEquality(onPoolSupplier, expectedOnPool, "supplier on Pool 1");
        assertEq(onPoolBorrower, 0, "borrower on Pool 1");
        assertEq(inP2PSupplier, expectedInP2P, "supplier in peer-to-peer 1");

        // NMAX-1 suppliers have up to suppliedAmount/2 waiting on pool
        uint256 NMAX = 20;
        createSigners(NMAX);

        // minus 1 because supplier1 must not be counted twice !
        uint256 amountPerSupplier = (suppliedAmount - borrowedAmount) / (2 * (NMAX - 1));
        uint256[] memory rates = new uint256[](NMAX);

        uint256 matchedAmount;
        for (uint256 i = 0; i < NMAX; i++) {
            if (suppliers[i] == supplier1) continue;

            rates[i] = IVToken(vDai).exchangeRateCurrent();

            matchedAmount += getBalanceOnVenus(amountPerSupplier, IVToken(vDai).exchangeRateCurrent());

            suppliers[i].approve(dai, amountPerSupplier);
            suppliers[i].supply(vDai, amountPerSupplier);
        }

        // supplier withdraws suppliedAmount.
        supplier1.withdraw(vDai, suppliedAmount);

        uint256 halfBorrowedAmount = borrowedAmount / 2;

        {
            // Check balances for supplier1.
            (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
            assertEq(onPoolSupplier, 0, "supplier on Pool 2");
            testEquality(inP2PSupplier, 0, "supplier in peer-to-peer 2");

            (inP2PBorrower, onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));

            uint256 expectedBorrowBalanceInP2P = halfBorrowedAmount.div(evoq.p2pBorrowIndex(vDai));
            uint256 expectedBorrowBalanceOnPool = halfBorrowedAmount.div(IVToken(vDai).borrowIndex());

            assertApproxEqAbs(inP2PBorrower, expectedBorrowBalanceInP2P, 2 * 10, "borrower in peer-to-peer 2");
            assertApproxEqAbs(onPoolBorrower, expectedBorrowBalanceOnPool, 1e10, "borrower on Pool 2");
        }

        // Check balances for the borrower.

        uint256 inP2P;
        uint256 onPool;

        // Now test for each individual supplier that replaced the original.
        for (uint256 i = 0; i < suppliers.length; i++) {
            if (suppliers[i] == supplier1) continue;

            (inP2P, onPool) = evoq.supplyBalanceInOf(vDai, address(suppliers[i]));

            assertEq(
                inP2P,
                getBalanceOnVenus(amountPerSupplier, rates[i]).div(evoq.p2pSupplyIndex(vDai)),
                "supplier in peer-to-peer"
            );
            assertEq(onPool, 0, "supplier on pool");

            (inP2P, onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(inP2P, 0, "borrower in peer-to-peer");
        }
    }

    function testWithdrawOnBehalf() public {
        uint256 bnbAmount = 1 ether;

        supplier1.supplyBNB{value: bnbAmount}(address(supplier1));

        (, uint256 onPool) = evoq.supplyBalanceInOf(vBnb, address(supplier1));
        testEquality(onPool, bnbAmount.div(IVToken(vBnb).exchangeRateCurrent()));

        // supplier1 has not approved wbnbgateway to be manager yet.
        hevm.expectRevert(PositionsManager.PermissionDenied.selector);
        supplier1.withdrawBNB(bnbAmount, address(supplier1));

        // borrower1 (attacker) is not manager.
        hevm.expectRevert(PositionsManager.PermissionDenied.selector);
        borrower1.withdraw(vBnb, bnbAmount, address(supplier1), address(borrower1));

        // after approve manager, supplier1 can withdraw BNB using wbnbGateway.
        supplier1.approveManager(address(wbnbGateway), true);
        supplier1.withdrawBNB(bnbAmount, address(supplier1));

        (, onPool) = evoq.supplyBalanceInOf(vBnb, address(supplier1));
        testEquality(onPool, 0);
    }

    struct Vars {
        uint256 LR;
        uint256 BPY;
        uint256 VBR;
        uint256 NVD;
        uint256 BP2PD;
        uint256 BP2PA;
        uint256 BP2PER;
    }

    function testDeltaWithdraw() public {
        // Allows only 10 unmatch borrowers.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 9e5, 3e6);

        uint256 borrowedAmount = 0.5 ether;
        uint256 collateral = 2 * borrowedAmount;
        uint256 suppliedAmount = 20 * borrowedAmount;
        uint256 expectedSupplyBalanceInP2P;

        // supplier1 and 20 borrowers are matched for suppliedAmount.
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        createSigners(30);
        uint256 matched;

        // 2 * NMAX borrowers borrow borrowedAmount.
        for (uint256 i; i < 20; i++) {
            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));
            borrowers[i].borrow(vDai, borrowedAmount, type(uint64).max);
            matched += borrowedAmount.div(evoq.p2pBorrowIndex(vDai));
        }

        {
            uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);
            expectedSupplyBalanceInP2P = suppliedAmount.div(p2pSupplyIndex);

            // Check balances after match of supplier1 and borrowers.
            (uint256 inP2PSupplier, uint256 onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
            assertApproxEqAbs(onPoolSupplier, 0, 20, "supplier on pool");
            assertApproxEqAbs(inP2PSupplier, expectedSupplyBalanceInP2P, 20, "supplier in P2P");

            uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);
            uint256 expectedBorrowBalanceInP2P = borrowedAmount.div(p2pBorrowIndex);
            uint256 inP2PBorrower;
            uint256 onPoolBorrower;

            for (uint256 i = 10; i < 20; i++) {
                (inP2PBorrower, onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
                assertEq(onPoolBorrower, 0);
                assertEq(inP2PBorrower, expectedBorrowBalanceInP2P, "borrower in P2P");
            }

            // Supplier withdraws max.
            // Should create a delta on borrowers side.
            supplier1.withdraw(vDai, type(uint256).max);

            // Check balances for supplier1.
            (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier1));
            assertEq(onPoolSupplier, 0);
            testEquality(inP2PSupplier, 0);

            // There should be a delta.
            // The amount unmatched during the withdraw.
            uint256 unmatched = 10 * inP2PBorrower.mul(evoq.p2pBorrowIndex(vDai));
            // The difference between the previous matched amount and the amout unmatched creates a delta.
            uint256 expectedP2PBorrowDeltaInUnderlying = (matched.mul(evoq.p2pBorrowIndex(vDai)) - unmatched);
            uint256 expectedP2PBorrowDelta =
                (matched.mul(evoq.p2pBorrowIndex(vDai)) - unmatched).div(IVToken(vDai).borrowIndex());

            (, uint256 p2pBorrowDelta,,) = evoq.deltas(vDai);
            assertEq(p2pBorrowDelta, expectedP2PBorrowDelta, "borrow delta not expected 1");

            // Borrow delta matching by new supplier.
            supplier2.approve(dai, expectedP2PBorrowDeltaInUnderlying / 2);
            supplier2.supply(vDai, expectedP2PBorrowDeltaInUnderlying / 2);

            (inP2PSupplier, onPoolSupplier) = evoq.supplyBalanceInOf(vDai, address(supplier2));
            expectedSupplyBalanceInP2P = (expectedP2PBorrowDeltaInUnderlying / 2).div(evoq.p2pSupplyIndex(vDai));

            (, p2pBorrowDelta,,) = evoq.deltas(vDai);
            testEquality(p2pBorrowDelta, expectedP2PBorrowDelta / 2, "borrow delta not expected 2");
            assertEq(onPoolSupplier, 0, "on pool supplier not 0");
            testEquality(inP2PSupplier, expectedSupplyBalanceInP2P, "in peer-to-peer supplier not expected");
        }

        {
            Vars memory oldVars;
            Vars memory newVars;

            (, oldVars.BP2PD,, oldVars.BP2PA) = evoq.deltas(vDai);
            oldVars.NVD = IVToken(vDai).borrowIndex();
            oldVars.BP2PER = evoq.p2pBorrowIndex(vDai);
            (, oldVars.BPY) = getApproxP2PRates(vDai);

            move1000BlocksForward(vDai);

            (, newVars.BP2PD,, newVars.BP2PA) = evoq.deltas(vDai);
            newVars.NVD = IVToken(vDai).borrowIndex();
            newVars.BP2PER = evoq.p2pBorrowIndex(vDai);
            (, newVars.BPY) = getApproxP2PRates(vDai);
            newVars.LR = IVToken(vDai).supplyRatePerBlock();
            newVars.VBR = IVToken(vDai).borrowRatePerBlock();

            uint256 shareOfTheDelta = newVars.BP2PD.mul(newVars.NVD).div(oldVars.BP2PER).div(newVars.BP2PA);

            uint256 expectedBP2PER = oldVars.BP2PER.mul(
                _computeCompoundedInterest(oldVars.BPY, 1000).mul(WAD - shareOfTheDelta)
                    + shareOfTheDelta.mul(newVars.NVD).div(oldVars.NVD)
            );

            assertApproxEqAbs(expectedBP2PER, newVars.BP2PER, (expectedBP2PER * 2) / 100, "BP2PER not expected");

            uint256 expectedBorrowBalanceInUnderlying = borrowedAmount.div(oldVars.BP2PER).mul(expectedBP2PER);

            for (uint256 i = 10; i < 20; i++) {
                (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
                assertApproxEqAbs(
                    inP2PBorrower.mul(newVars.BP2PER),
                    expectedBorrowBalanceInUnderlying,
                    (expectedBorrowBalanceInUnderlying * 2) / 100,
                    "not expected underlying balance"
                );
                assertEq(onPoolBorrower, 0);
            }
        }

        // Borrow delta reduction with borrowers repaying
        for (uint256 i = 10; i < 20; i++) {
            borrowers[i].approve(dai, borrowedAmount);
            borrowers[i].repay(vDai, borrowedAmount);
        }

        (, uint256 p2pBorrowDeltaAfter,,) = evoq.deltas(vDai);
        assertApproxEqAbs(p2pBorrowDeltaAfter, 0, 1, "borrow delta 2");

        (uint256 inP2PSupplier2, uint256 onPoolSupplier2) = evoq.supplyBalanceInOf(vDai, address(supplier2));

        testEquality(inP2PSupplier2, expectedSupplyBalanceInP2P);
        assertEq(onPoolSupplier2, 0);
    }

    function testDeltaWithdrawAll() public {
        // Allows only 10 unmatch borrowers.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 9e5, 3e6);

        uint256 borrowedAmount = 0.5 ether;
        uint256 collateral = 2 * borrowedAmount;
        uint256 suppliedAmount = 20 * borrowedAmount + 1e12;

        // supplier1 and 20 borrowers are matched for suppliedAmount.
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(vDai, suppliedAmount);

        createSigners(20);

        // 2 * NMAX borrowers borrow borrowedAmount.
        for (uint256 i = 0; i < 20; i++) {
            borrowers[i].approve(usdc, (collateral));
            borrowers[i].supply(vUsdc, (collateral));
            borrowers[i].borrow(vDai, borrowedAmount + i, type(uint64).max);
        }

        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(inP2P, (borrowedAmount + i).div(evoq.p2pBorrowIndex(vDai)), "inP2P");
            assertEq(onPool, 0, "onPool");
        }

        // Supplier withdraws max.
        // Should create a delta on borrowers side.
        supplier1.withdraw(vDai, type(uint256).max);

        for (uint256 i = 0; i < 10; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(inP2P, 0, string.concat("inP2P", Strings.toString(i)));
            assertApproxEqAbs(
                onPool,
                (borrowedAmount + i).div(IVToken(vDai).borrowIndex()),
                2 * 1e8,
                string.concat("onPool", Strings.toString(i))
            );
        }
        for (uint256 i = 10; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(
                inP2P, (borrowedAmount + i).div(evoq.p2pBorrowIndex(vDai)), string.concat("inP2P", Strings.toString(i))
            );
            assertEq(onPool, 0, string.concat("onPool", Strings.toString(i)));
        }

        (uint256 p2pSupplyDelta, uint256 p2pBorrowDelta, uint256 p2pSupplyAmount, uint256 p2pBorrowAmount) =
            evoq.deltas(vDai);

        assertEq(p2pSupplyDelta, 0, "p2pSupplyDelta");
        assertApproxEqAbs(
            p2pBorrowDelta, (10 * borrowedAmount).div(IVToken(vDai).borrowIndex()), 2 * 1e9, "p2pBorrowDelta"
        );
        assertApproxEqAbs(p2pSupplyAmount, 0, 1, "p2pSupplyAmount");
        assertApproxEqAbs(p2pBorrowAmount, (10 * borrowedAmount).div(evoq.p2pBorrowIndex(vDai)), 1e2, "p2pBorrowAmount");

        move100BlocksForward(vDai);

        for (uint256 i = 0; i < 20; i++) {
            borrowers[i].approve(dai, type(uint256).max);
            borrowers[i].repay(vDai, type(uint256).max);
            borrowers[i].withdraw(vUsdc, type(uint256).max);
        }

        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = evoq.borrowBalanceInOf(vDai, address(borrowers[i]));
            assertEq(inP2P, 0, "inP2P");
            assertEq(onPool, 0, "onPool");
        }
    }

    function testShouldNotWithdrawWhenUnderCollaterized() public {
        uint256 toSupply = 100 ether;
        uint256 toBorrow = toSupply / 2;

        // supplier1 deposits collateral.
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);

        // supplier2 deposits collateral.
        supplier2.approve(dai, toSupply);
        supplier2.supply(vDai, toSupply);

        // supplier1 tries to withdraw more than allowed.
        supplier1.borrow(vUsdc, (toBorrow));
        hevm.expectRevert(abi.encodeWithSignature("UnauthorisedWithdraw()"));
        supplier1.withdraw(vDai, toSupply);
    }

    // Test attack.
    // Should be possible to withdraw amount while an attacker sends vToken to trick Evoq contract.
    function testWithdrawWhileAttackerSendsCToken() public {
        Attacker attacker = new Attacker();
        deal(dai, address(attacker), type(uint256).max / 2);

        uint256 toSupply = 100 ether;
        uint256 collateral = 2 * toSupply;
        uint256 toBorrow = toSupply;

        // Attacker sends vToken to evoq contract.
        attacker.approve(dai, vDai, toSupply);
        attacker.deposit(vDai, toSupply);
        attacker.transfer(dai, address(evoq), toSupply);

        // supplier1 deposits collateral.
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);

        // borrower1 deposits collateral.
        borrower1.approve(usdc, (collateral));
        borrower1.supply(vUsdc, (collateral));

        // supplier1 tries to withdraw.
        borrower1.borrow(vDai, toBorrow);
        supplier1.withdraw(vDai, toSupply);
    }

    function testShouldNotWithdrawZero() public {
        hevm.expectRevert(PositionsManager.AmountIsZero.selector);
        evoq.withdraw(vDai, 0);
    }

    function testWithdrawnOnPoolThreshold() public {
        uint256 amountWithdrawn = 1e6;

        supplier1.approve(dai, 1 ether);
        supplier1.supply(vDai, 1 ether);

        hevm.expectRevert(abi.encodeWithSignature("WithdrawTooSmall()"));
        supplier1.withdraw(vDai, amountWithdrawn);
    }

    function testFailInfiniteWithdraw() public {
        uint256 balanceAtTheBeginning = ERC20(dai).balanceOf(address(supplier1));

        uint256 amount = 1 ether;
        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);
        supplier2.approve(dai, 9 * amount);
        supplier2.supply(vDai, 9 * amount);
        borrower1.approve(wBnb, 10 * amount);
        borrower1.supply(vBnb, 10 * amount);
        borrower1.borrow(vDai, 10 * amount);

        evoq.setIsP2PDisabled(vDai, true);

        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);
        supplier1.withdraw(vDai, amount);

        assertTrue(ERC20(dai).balanceOf(address(supplier1)) > balanceAtTheBeginning);
    }

    function testShouldNotFreezeMarketWithExchangeRatePump() public {
        uint256 amount = 500_000e6;
        supplier1.approve(usdc, amount);
        supplier1.supply(vUsdc, amount);

        hevm.roll(block.number + 1);

        hevm.prank(address(supplier1));
        ERC20(usdc).transfer(vUsdc, 200e6);

        supplier1.withdraw(vUsdc, type(uint256).max);
    }

    function testShouldBeAbleToWithdrawAfterDelayWhenPartiallyMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        hevm.roll(block.number + 100);

        supplier1.withdraw(vDai, type(uint256).max);
    }

    function testShouldWithdrawToReceiver() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, 2 * amount);
        supplier1.supply(vDai, 2 * amount);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(supplier2));

        supplier1.withdraw(vDai, amount, address(supplier2));

        assertEq(ERC20(dai).balanceOf(address(supplier2)), balanceBefore + amount);
    }

    function testShouldPreventWithdrawWhenBorrowCapReached() public {
        createMarket(vCake);

        uint256 venusCollateralAmount = 7_000_000 ether;
        deal(cake, address(borrower1), venusCollateralAmount);
        borrower1.venusSupply(vCake, venusCollateralAmount);

        uint256 borrowCap = evoq.comptroller().borrowCaps(vCake); // 3,749,000 ether
        uint256 totalborrow = IVToken(vCake).totalBorrows(); // 501,615.1931537 ether
        if (borrowCap > totalborrow) {
            borrower1.venusBorrow(vCake, evoq.comptroller().borrowCaps(vCake) - IVToken(vCake).totalBorrows() - 1 ether);
        }

        deal(cake, address(supplier1), 110 ether);
        supplier1.approve(cake, 110 ether);
        supplier1.supply(vCake, 110 ether);

        deal(dai, address(borrower2), 100_000 ether);
        borrower2.approve(dai, 100_000 ether);
        borrower2.supply(vDai, 100_000 ether);
        borrower2.borrow(vCake, 10 ether);

        vm.expectRevert("market borrow cap reached");
        supplier1.withdraw(vCake, type(uint256).max);
    }
}
