// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestFees is TestSetup {
    using CompoundMath for uint256;

    address[] vDaiArray = [vDai];
    uint256[] public amountArray = [1 ether];
    uint256[] public maxAmountArray = [type(uint256).max];

    function testShouldNotBePossibleToSetFeesHigherThan100Percent() public {
        hevm.expectRevert(abi.encodeWithSignature("ExceedsMaxBasisPoints()"));
        evoq.setReserveFactor(vUsdc, 10_001);
    }

    function testShouldNotBePossibleToSetP2PIndexCursorHigherThan100Percent() public {
        hevm.expectRevert(abi.encodeWithSignature("ExceedsMaxBasisPoints()"));
        evoq.setP2PIndexCursor(vUsdc, 10_001);
    }

    function testOnlyOwnerCanSetTreasuryVault() public {
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setTreasuryVault(address(borrower1));
    }

    function testOwnerShouldBeAbleToClaimFees() public {
        uint256 balanceBefore = ERC20(dai).balanceOf(evoq.treasuryVault());
        _createFeeOnEvoq(1_000);
        evoq.claimToTreasury(vDaiArray, maxAmountArray);
        uint256 balanceAfter = ERC20(dai).balanceOf(evoq.treasuryVault());

        assertLt(balanceBefore, balanceAfter);
    }

    // function testShouldRevertWhenClaimingToZeroAddress() public {
    //     // Set treasury vault to 0x.
    //     evoq.setTreasuryVault(address(0));

    //     _createFeeOnEvoq(1_000);

    //     hevm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
    //     evoq.claimToTreasury(vDaiArray, amountArray);
    // }

    function testShouldCollectTheRightAmountOfFees() public {
        uint16 reserveFactor = 1_000;
        evoq.setReserveFactor(vDai, reserveFactor); // 10%

        uint256 balanceBefore = ERC20(dai).balanceOf(evoq.treasuryVault()); // 0
        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, 100 ether);
        supplier1.borrow(vDai, 50 ether);

        uint256 oldSupplyExRate = evoq.p2pSupplyIndex(vDai); // 200000001779786842000000000
        uint256 oldBorrowExRate = evoq.p2pBorrowIndex(vDai); // 200000001779786842000000000

        (uint256 supplyP2PBPY, uint256 borrowP2PBPY) = getApproxP2PRates(vDai);

        uint256 newSupplyExRate = oldSupplyExRate.mul(_computeCompoundedInterest(supplyP2PBPY, 1000));
        uint256 newBorrowExRate = oldBorrowExRate.mul(_computeCompoundedInterest(borrowP2PBPY, 1000));

        uint256 expectedFees =
            (50 * WAD).mul(newBorrowExRate.div(oldBorrowExRate) - newSupplyExRate.div(oldSupplyExRate)); // 0.00001427365222 DAI

        move1000BlocksForward(vDai);

        supplier1.repay(vDai, type(uint256).max);
        evoq.claimToTreasury(vDaiArray, maxAmountArray);
        uint256 balanceAfter = ERC20(dai).balanceOf(evoq.treasuryVault()); // 0.00001427396074 DAI
        uint256 gainedByTreasury = balanceAfter - balanceBefore;

        assertApproxEqAbs(gainedByTreasury, expectedFees, (expectedFees * 1) / 10_000, "Fees collected");
    }

    function testShouldNotClaimFeesIfFactorIsZero() public {
        uint256 balanceBefore = ERC20(dai).balanceOf(address(this));

        _createFeeOnEvoq(0);

        evoq.claimToTreasury(vDaiArray, maxAmountArray);

        uint256 balanceAfter = ERC20(dai).balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore);
    }

    function testShouldPayFee() public {
        uint16 reserveFactor = 1_000;
        uint256 bigAmount = 100_000 ether;
        uint256 smallAmount = 0.00001 ether;
        evoq.setReserveFactor(vDai, reserveFactor); // 10%

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, smallAmount);
        supplier1.borrow(vDai, smallAmount / 2);

        supplier2.approve(dai, type(uint256).max);
        supplier2.supply(vDai, bigAmount);
        supplier2.borrow(vDai, bigAmount / 2);

        move1000BlocksForward(vDai);

        supplier1.repay(vDai, type(uint256).max);
    }

    function testShouldReduceTheFeeToRepay() public {
        uint16 reserveFactor = 1_000;
        uint256 bigAmount = 100_000 ether;
        uint256 smallAmount = 0.00001 ether;
        evoq.setReserveFactor(vDai, reserveFactor); // 10%

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, smallAmount);
        supplier1.borrow(vDai, smallAmount / 2);

        supplier2.approve(dai, type(uint256).max);
        supplier2.supply(vDai, bigAmount);
        supplier2.borrow(vDai, bigAmount / 2);

        move1000BlocksForward(vDai);

        supplier1.repay(vDai, type(uint256).max);
        supplier2.repay(vDai, type(uint256).max);
    }

    function testShouldNotClaimXvsRewards() public {
        uint256 amount = 1_000 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);
        supplier2.approve(dai, type(uint256).max);
        supplier2.supply(vDai, amount);

        move100BlocksForward(vDai);

        // Claim rewards for supplier1 and supplier2. Only XVS rewards for supplier2 are left on the contract.
        supplier1.claimRewards(vDaiArray);

        // Try to claim XVS to treasury.
        uint256 balanceBefore = ERC20(xvs).balanceOf(address(evoq));
        address[] memory vXvsArray = new address[](1);
        vXvsArray[0] = vXvs;
        evoq.claimToTreasury(vXvsArray, amountArray);
        uint256 balanceAfter = ERC20(xvs).balanceOf(address(evoq));

        assertEq(balanceAfter, balanceBefore);
    }

    /// HELPERS ///

    function _createFeeOnEvoq(uint16 _factor) internal {
        evoq.setReserveFactor(vDai, _factor);

        // Increase blocks so that rates update.
        hevm.roll(block.number + 1);

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, 100 * WAD);
        supplier1.borrow(vDai, 50 * WAD);

        move1000BlocksForward(vDai);

        supplier1.repay(vDai, type(uint256).max);
    }
}
