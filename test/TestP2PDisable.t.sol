// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestP2PDisable is TestSetup {
    function testShouldNotMatchSupplyDeltaWithP2PDisabled() public {
        uint256 nSuppliers = 3;
        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = nSuppliers * suppliedAmount;
        uint256 collateralAmount = 2 * borrowedAmount;

        borrower1.approve(usdc, type(uint256).max);
        borrower1.supply(vUsdc, (collateralAmount));
        borrower1.borrow(vDai, borrowedAmount);

        for (uint256 i; i < nSuppliers; i++) {
            suppliers[i].approve(dai, type(uint256).max);
            suppliers[i].supply(vDai, suppliedAmount);
        }

        moveOneBlockForwardBorrowRepay();

        // Create delta.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 3e6, 0);
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        // Delta must be greater than 0.
        (uint256 p2pSupplyDelta,,,) = evoq.deltas(vDai);
        assertGt(p2pSupplyDelta, 0);

        evoq.setIsP2PDisabled(vDai, true);

        // The delta should not be reduced.
        borrower1.borrow(vDai, borrowedAmount);
        (uint256 newP2PSupplyDelta,,,) = evoq.deltas(vDai);
        assertEq(newP2PSupplyDelta, p2pSupplyDelta);
        // Borrower1 should not be matched P2P.
        (uint256 inP2P,) = evoq.borrowBalanceInOf(vDai, address(borrower1));
        assertEq(inP2P, 0);
    }

    function testShouldNotMatchBorrowDeltaWithP2PDisabled() public {
        uint256 nBorrowers = 3;
        uint256 borrowAmount = 1 ether;
        uint256 collateralAmount = 2 * borrowAmount;
        uint256 supplyAmount = nBorrowers * borrowAmount;

        supplier1.approve(usdc, type(uint256).max);
        supplier1.supply(vUsdc, (supplyAmount));

        for (uint256 i; i < nBorrowers; i++) {
            borrowers[i].approve(dai, type(uint256).max);
            borrowers[i].approve(usdc, type(uint256).max);
            borrowers[i].supply(vDai, collateralAmount);
            borrowers[i].borrow(vUsdc, (borrowAmount));
        }

        // Create delta.
        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 3e6);
        supplier1.withdraw(vUsdc, type(uint256).max);

        // Delta must be greater than 0.
        (, uint256 p2pBorrowDelta,,) = evoq.deltas(vUsdc);
        assertGt(p2pBorrowDelta, 0);

        evoq.setIsP2PDisabled(vUsdc, true);

        // The delta should not be reduced.
        supplier1.supply(vUsdc, (supplyAmount * 2));
        (, uint256 newP2PBorrowDelta,,) = evoq.deltas(vUsdc);
        assertEq(newP2PBorrowDelta, p2pBorrowDelta);
        // Supplier1 should not be matched P2P.
        (uint256 inP2P,) = evoq.supplyBalanceInOf(vUsdc, address(supplier1));
        assertApproxEqAbs(inP2P, 0, 1e4);
    }

    function testShouldBeAbleToWithdrawRepayAfterPoolPause() public {
        uint256 amount = 100_000 ether;

        // Create some peer-to-peer matching.
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);
        borrower1.approve(usdc, type(uint256).max);
        borrower1.supply(vUsdc, (amount * 2));
        borrower1.borrow(vDai, amount);

        // Increase deltas.
        evoq.increaseP2PDeltas(vDai, type(uint256).max);

        // Pause borrow on pool.
        address[] memory vTokens = new address[](1);
        vTokens[0] = address(vDai);
        IComptroller.Action[] memory actions = new IComptroller.Action[](2);
        actions[0] = IComptroller.Action.MINT;
        actions[1] = IComptroller.Action.BORROW;
        vm.prank(comptroller.admin());
        comptroller._setActionsPaused(vTokens, actions, true);

        // Withdraw and repay peer-to-peer matched positions.
        supplier1.withdraw(vDai, amount - 1e9);
        // Bypass the borrow repay in the same block by overwritting the storage slot lastBorrowBlock[borrower1].
        hevm.store(address(evoq), keccak256(abi.encode(address(borrower1), 30)), 0);
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);
    }
}
