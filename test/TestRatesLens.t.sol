// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestRatesLens is TestSetup {
    using CompoundMath for uint256;

    function testGetRatesPerBlock() public {
        supplier1.venusSupply(vDai, 1 ether); // Update pool rates.

        hevm.roll(block.number + 1_000);
        (uint256 p2pSupplyRate, uint256 p2pBorrowRate, uint256 poolSupplyRate, uint256 poolBorrowRate) =
            lens.getRatesPerBlock(vDai);

        (uint256 expectedP2PSupplyRate, uint256 expectedP2PBorrowRate) = getApproxP2PRates(vDai);
        uint256 expectedPoolSupplyRate = IVToken(vDai).supplyRatePerBlock();
        uint256 expectedPoolBorrowRate = IVToken(vDai).borrowRatePerBlock();

        assertApproxEqAbs(p2pSupplyRate, expectedP2PSupplyRate, 1);
        assertApproxEqAbs(p2pBorrowRate, expectedP2PBorrowRate, 1);
        assertApproxEqAbs(poolSupplyRate, expectedPoolSupplyRate, 1);
        assertApproxEqAbs(poolBorrowRate, expectedPoolBorrowRate, 1);
    }

    function testSupplyRateShouldEqual0WhenNoSupply() public {
        uint256 supplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(vDai, address(supplier1));

        assertEq(supplyRatePerBlock, 0);
    }

    function testBorrowRateShouldEqual0WhenNoBorrow() public {
        uint256 borrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(vDai, address(borrower1));

        assertEq(borrowRatePerBlock, 0);
    }

    function testUserSupplyRateShouldEqualPoolRateWhenNotMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        uint256 supplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(vDai, address(supplier1));

        assertApproxEqAbs(supplyRatePerBlock, IVToken(vDai).supplyRatePerBlock(), 1);
    }

    function testUserBorrowRateShouldEqualPoolRateWhenNotMatched() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        uint256 borrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(vDai, address(borrower1));

        assertApproxEqAbs(borrowRatePerBlock, IVToken(vDai).borrowRatePerBlock(), 1);
    }

    function testUserRatesShouldEqualP2PRatesWhenFullyMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(wBnb, amount);
        supplier1.supply(vBnb, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        uint256 supplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(vDai, address(supplier1));
        uint256 borrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(vDai, address(borrower1));
        (uint256 p2pSupplyRate, uint256 p2pBorrowRate,,) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(supplyRatePerBlock, p2pSupplyRate, 1, "unexpected supply rate");
        assertApproxEqAbs(borrowRatePerBlock, p2pBorrowRate, 1, "unexpected borrow rate");
    }

    function testUserSupplyRateShouldEqualMidrateWhenHalfMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(wBnb, amount);
        supplier1.supply(vBnb, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        uint256 supplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(vDai, address(supplier1));
        (uint256 p2pSupplyRate,, uint256 poolSupplyRate,) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(supplyRatePerBlock, (p2pSupplyRate + poolSupplyRate) / 2, 1);
    }

    function testUserBorrowRateShouldEqualMidrateWhenHalfMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(wBnb, amount);
        supplier1.supply(vBnb, amount);
        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);

        supplier1.approve(dai, amount / 2);
        supplier1.supply(vDai, amount / 2);
        borrower1.borrow(vDai, amount);

        uint256 borrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(vDai, address(borrower1));
        (, uint256 p2pBorrowRate,, uint256 poolBorrowRate) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(borrowRatePerBlock, (p2pBorrowRate + poolBorrowRate) / 2, 1);
    }

    function testSupplyRateShouldEqualPoolRateWithFullSupplyDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        (uint256 p2pSupplyRate,, uint256 poolSupplyRate,) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(p2pSupplyRate, poolSupplyRate, 1);
    }

    function testBorrowRateShouldEqualPoolRateWithFullBorrowDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        supplier1.withdraw(vDai, type(uint256).max);

        (, uint256 p2pBorrowRate,, uint256 poolBorrowRate) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(p2pBorrowRate, poolBorrowRate, 1);
    }

    function testNextSupplyRateShouldEqual0WhenNoSupply() public {
        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), 0);

        assertEq(supplyRatePerBlock, 0, "non zero supply rate per block");
        assertEq(balanceOnPool, 0, "non zero pool balance");
        assertEq(balanceInP2P, 0, "non zero p2p balance");
        assertEq(totalBalance, 0, "non zero total balance");
    }

    function testNextBorrowRateShouldEqual0WhenNoBorrow() public {
        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), 0);

        assertEq(borrowRatePerBlock, 0, "non zero borrow rate per block");
        assertEq(balanceOnPool, 0, "non zero pool balance");
        assertEq(balanceInP2P, 0, "non zero p2p balance");
        assertEq(totalBalance, 0, "non zero total balance");
    }

    function testNextSupplyRateShouldEqualCurrentRateWhenNoNewSupply() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 1000);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), 0);

        uint256 expectedSupplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(vDai, address(supplier1));
        (uint256 expectedBalanceOnPool, uint256 expectedBalanceInP2P, uint256 expectedTotalBalance) =
            lens.getCurrentSupplyBalanceInOf(vDai, address(supplier1));

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertEq(supplyRatePerBlock, expectedSupplyRatePerBlock, "unexpected supply rate per block");
        assertEq(balanceOnPool, expectedBalanceOnPool, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedTotalBalance, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualCurrentRateWhenNoNewBorrow() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1000);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), 0);

        uint256 expectedBorrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(vDai, address(borrower1));
        (uint256 expectedBalanceOnPool, uint256 expectedBalanceInP2P, uint256 expectedTotalBalance) =
            lens.getCurrentBorrowBalanceInOf(vDai, address(borrower1));

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertEq(borrowRatePerBlock, expectedBorrowRatePerBlock, "unexpected borrow rate per block");
        assertEq(balanceOnPool, expectedBalanceOnPool, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedTotalBalance, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualPoolRateWhenNoBorrowerOnPool() public {
        uint256 amount = 10_000 ether;

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        uint256 expectedSupplyRatePerBlock = IVToken(vDai).supplyRatePerBlock();
        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(supplyRatePerBlock, expectedSupplyRatePerBlock, 5 * 1e9, "unexpected supply rate per block");
        assertEq(balanceOnPool, amount.div(poolSupplyIndex).mul(poolSupplyIndex), "unexpected pool balance");
        assertEq(balanceInP2P, 0, "unexpected p2p balance");
        assertEq(totalBalance, amount.div(poolSupplyIndex).mul(poolSupplyIndex), "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualPoolRateWhenNoSupplierOnPool() public {
        uint256 amount = 10_000 ether;

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(supplier1), amount);

        uint256 expectedBorrowRatePerBlock = IVToken(vDai).borrowRatePerBlock();

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertApproxEqAbs(borrowRatePerBlock, expectedBorrowRatePerBlock, 7 * 1e9, "unexpected borrow rate per block");
        assertApproxEqAbs(balanceOnPool, amount, 1, "unexpected pool balance");
        assertEq(balanceInP2P, 0, "unexpected p2p balance");
        assertApproxEqAbs(totalBalance, amount, 1, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualP2PRateWhenFullMatch() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1000);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        (uint256 p2pSupplyRatePerBlock,,,) = lens.getRatesPerBlock(vDai);

        evoq.updateP2PIndexes(vDai);
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);

        uint256 expectedBalanceInP2P = amount.div(p2pSupplyIndex).mul(p2pSupplyIndex);

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(supplyRatePerBlock, p2pSupplyRatePerBlock, 5 * 1e9, "unexpected supply rate per block");
        assertEq(balanceOnPool, 0, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualP2PRateWhenFullMatch() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 1000);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount);

        (, uint256 p2pBorrowRatePerBlock,,) = lens.getRatesPerBlock(vDai);

        evoq.updateP2PIndexes(vDai);
        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);

        uint256 expectedBalanceInP2P = amount.div(p2pBorrowIndex).mul(p2pBorrowIndex);

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertApproxEqAbs(borrowRatePerBlock, p2pBorrowRatePerBlock, 6 * 1e9, "unexpected borrow rate per block");
        assertApproxEqAbs(balanceOnPool, 0, 1e6, "unexpected pool balance"); // venus rounding error at supply
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualMidrateWhenHalfMatch() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        (uint256 p2pSupplyRatePerBlock,, uint256 poolSupplyRatePerBlock,) = lens.getRatesPerBlock(vDai);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);

        uint256 expectedBalanceOnPool = (amount / 2).div(poolSupplyIndex).mul(poolSupplyIndex);
        uint256 expectedBalanceInP2P = (amount / 2).div(p2pSupplyIndex).mul(p2pSupplyIndex);

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(
            supplyRatePerBlock,
            (p2pSupplyRatePerBlock + poolSupplyRatePerBlock) / 2,
            1e6,
            "unexpected supply rate per block"
        );
        assertEq(balanceOnPool, expectedBalanceOnPool, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceOnPool + expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualMidrateWhenHalfMatch() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount / 2);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount);

        (, uint256 p2pBorrowRatePerBlock,, uint256 poolBorrowRatePerBlock) = lens.getRatesPerBlock(vDai);

        uint256 poolBorrowIndex = IVToken(vDai).borrowIndex();
        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);

        uint256 expectedBalanceOnPool = (amount / 2).div(poolBorrowIndex).mul(poolBorrowIndex);
        uint256 expectedBalanceInP2P = (amount / 2).div(p2pBorrowIndex).mul(p2pBorrowIndex);

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertApproxEqAbs(
            borrowRatePerBlock,
            (p2pBorrowRatePerBlock + poolBorrowRatePerBlock) / 2,
            1,
            "unexpected borrow rate per block"
        );
        assertApproxEqAbs(balanceOnPool, expectedBalanceOnPool, 1e9, "unexpected pool balance");
        assertApproxEqAbs(balanceInP2P, expectedBalanceInP2P, 1e9, "unexpected p2p balance");
        assertApproxEqAbs(totalBalance, expectedBalanceOnPool + expectedBalanceInP2P, 1e9, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualPoolRateWhenFullMatchButP2PDisabled() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1000);

        evoq.setIsP2PDisabled(vDai, true);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        uint256 expectedSupplyRatePerBlock = IVToken(vDai).supplyRatePerBlock();
        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();

        assertApproxEqAbs(supplyRatePerBlock, expectedSupplyRatePerBlock, 5 * 1e9, "unexpected supply rate per block");
        assertEq(balanceOnPool, amount.div(poolSupplyIndex).mul(poolSupplyIndex), "unexpected pool balance");
        assertEq(balanceInP2P, 0, "unexpected p2p balance");
        assertEq(totalBalance, amount.div(poolSupplyIndex).mul(poolSupplyIndex), "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualPoolRateWhenFullMatchButP2PDisabled() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 1000);

        evoq.setIsP2PDisabled(vDai, true);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount);

        uint256 expectedBorrowRatePerBlock = IVToken(vDai).borrowRatePerBlock();

        assertApproxEqAbs(borrowRatePerBlock, expectedBorrowRatePerBlock, 7 * 1e9, "unexpected borrow rate per block");
        assertApproxEqAbs(balanceOnPool, amount, 2 * 1, "unexpected pool balance");
        assertEq(balanceInP2P, 0, "unexpected p2p balance");
        assertApproxEqAbs(totalBalance, amount, 2 * 1, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualP2PRateWhenDoubleSupply() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount / 2);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount / 2);

        (uint256 p2pSupplyRatePerBlock,,,) = lens.getRatesPerBlock(vDai);

        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);
        uint256 expectedBalanceInP2P = amount.div(p2pSupplyIndex).mul(p2pSupplyIndex);

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(supplyRatePerBlock, p2pSupplyRatePerBlock, 3 * 1e9, "unexpected supply rate per block");
        assertEq(balanceOnPool, 0, "unexpected pool balance");
        assertApproxEqAbs(balanceInP2P, expectedBalanceInP2P, 1e9, "unexpected p2p balance");
        assertApproxEqAbs(totalBalance, expectedBalanceInP2P, 1e9, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualP2PRateWhenDoubleBorrow() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount / 2);

        (, uint256 p2pBorrowRatePerBlock,,) = lens.getRatesPerBlock(vDai);

        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);
        uint256 expectedBalanceInP2P = amount.div(p2pBorrowIndex).mul(p2pBorrowIndex);

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertApproxEqAbs(borrowRatePerBlock, p2pBorrowRatePerBlock, 2 * 1e9, "unexpected borrow rate per block");
        assertApproxEqAbs(balanceOnPool, 0, 1e9, "unexpected pool balance"); // venus rounding errors
        assertApproxEqAbs(balanceInP2P, expectedBalanceInP2P, 1e9, "unexpected p2p balance");
        assertApproxEqAbs(totalBalance, expectedBalanceInP2P, 1e9, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualP2PRateWithFullBorrowDeltaAndNoBorrowerOnPool() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        supplier1.withdraw(vDai, type(uint256).max);

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        (uint256 p2pSupplyRatePerBlock,,,) = lens.getRatesPerBlock(vDai);

        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);
        uint256 expectedBalanceInP2P = amount.div(p2pSupplyIndex).mul(p2pSupplyIndex);

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(supplyRatePerBlock, p2pSupplyRatePerBlock, 5 * 1e9, "unexpected supply rate per block");
        assertEq(balanceOnPool, 0, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualP2PRateWithFullSupplyDeltaAndNoSupplierOnPool() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount);

        (, uint256 p2pBorrowRatePerBlock,,) = lens.getRatesPerBlock(vDai);

        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);
        uint256 expectedBalanceInP2P = amount.div(p2pBorrowIndex).mul(p2pBorrowIndex);

        assertGt(borrowRatePerBlock, 0, "zero borrow rate per block");
        assertApproxEqAbs(borrowRatePerBlock, p2pBorrowRatePerBlock, 6 * 1e9, "unexpected borrow rate per block");
        assertEq(balanceOnPool, 0, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextSupplyRateShouldEqualMidrateWithHalfBorrowDeltaAndNoBorrowerOnPool() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        supplier1.approve(dai, amount / 2);
        supplier1.supply(vDai, amount / 2);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 1);

        supplier1.withdraw(vDai, type(uint256).max);

        uint256 daiBorrowdelta; // should be (amount / 2) but venus rounding leads to a slightly different amount which we need to compute
        {
            (, uint256 p2pBorrowDelta,,) = evoq.deltas(vDai);
            daiBorrowdelta = p2pBorrowDelta.mul(IVToken(vDai).borrowIndex());
        }

        (uint256 supplyRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserSupplyRatePerBlock(vDai, address(supplier1), amount);

        (uint256 p2pSupplyRatePerBlock,, uint256 poolSupplyRatePerBlock,) = lens.getRatesPerBlock(vDai);

        uint256 poolSupplyIndex = IVToken(vDai).exchangeRateCurrent();
        uint256 p2pSupplyIndex = evoq.p2pSupplyIndex(vDai);

        uint256 expectedBalanceOnPool = (amount - daiBorrowdelta).div(poolSupplyIndex).mul(poolSupplyIndex);
        uint256 expectedBalanceInP2P = daiBorrowdelta.div(p2pSupplyIndex).mul(p2pSupplyIndex);

        assertGt(supplyRatePerBlock, 0, "zero supply rate per block");
        assertApproxEqAbs(
            supplyRatePerBlock,
            (p2pSupplyRatePerBlock + poolSupplyRatePerBlock) / 2,
            100,
            "unexpected supply rate per block"
        );
        assertEq(balanceOnPool, expectedBalanceOnPool, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceOnPool + expectedBalanceInP2P, "unexpected total balance");
    }

    function testNextBorrowRateShouldEqualMidrateWithHalfSupplyDeltaAndNoSupplierOnPool() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        supplier1.approve(dai, amount / 2);
        supplier1.supply(vDai, amount / 2);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 1);

        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        uint256 daiSupplydelta; // should be (amount / 2) but venus rounding leads to a slightly different amount which we need to compute
        {
            (uint256 p2pSupplyDelta,,,) = evoq.deltas(vDai);
            daiSupplydelta = p2pSupplyDelta.mul(IVToken(vDai).exchangeRateCurrent());
        }

        (uint256 borrowRatePerBlock, uint256 balanceOnPool, uint256 balanceInP2P, uint256 totalBalance) =
            lens.getNextUserBorrowRatePerBlock(vDai, address(borrower1), amount);

        (, uint256 p2pBorrowRatePerBlock,, uint256 poolBorrowRatePerBlock) = lens.getRatesPerBlock(vDai);

        uint256 poolBorrowIndex = IVToken(vDai).borrowIndex();
        uint256 p2pBorrowIndex = evoq.p2pBorrowIndex(vDai);

        uint256 expectedBalanceOnPool = (amount - daiSupplydelta).div(poolBorrowIndex).mul(poolBorrowIndex);
        uint256 expectedBalanceInP2P = daiSupplydelta.div(p2pBorrowIndex).mul(p2pBorrowIndex);

        assertGt(borrowRatePerBlock, p2pBorrowRatePerBlock, "borrow rate higher than p2p rate");
        assertLt(borrowRatePerBlock, poolBorrowRatePerBlock, "borrow rate lower than pool rate");
        assertApproxEqAbs(
            borrowRatePerBlock,
            (p2pBorrowRatePerBlock + poolBorrowRatePerBlock) / 2,
            2 * 100,
            "unexpected borrow rate per block"
        );
        assertEq(balanceOnPool, expectedBalanceOnPool, "unexpected pool balance");
        assertEq(balanceInP2P, expectedBalanceInP2P, "unexpected p2p balance");
        assertEq(totalBalance, expectedBalanceOnPool + expectedBalanceInP2P, "unexpected total balance");
    }

    function testRatesShouldBeConstantWhenSupplyDeltaWithoutInteraction() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        borrower2.approve(wBnb, amount);
        borrower2.supply(vBnb, amount);
        borrower2.borrow(vDai, amount / 2);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 1);

        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(vDai, type(uint256).max);

        (
            uint256 p2pSupplyRateBefore,
            uint256 p2pBorrowRateBefore,
            uint256 poolSupplyRateBefore,
            uint256 poolBorrowRateBefore
        ) = lens.getRatesPerBlock(vDai);

        hevm.roll(block.number + 1_000_000);

        (
            uint256 p2pSupplyRateAfter,
            uint256 p2pBorrowRateAfter,
            uint256 poolSupplyRateAfter,
            uint256 poolBorrowRateAfter
        ) = lens.getRatesPerBlock(vDai);

        assertEq(p2pSupplyRateBefore, p2pSupplyRateAfter);
        assertEq(p2pBorrowRateBefore, p2pBorrowRateAfter);
        assertEq(poolSupplyRateBefore, poolSupplyRateAfter);
        assertEq(poolBorrowRateBefore, poolBorrowRateAfter);
    }

    function testAverageSupplyRateShouldEqual0WhenNoSupply() public {
        (uint256 supplyRatePerBlock, uint256 p2pSupplyAmount, uint256 poolSupplyAmount) =
            lens.getAverageSupplyRatePerBlock(vDai);

        assertEq(supplyRatePerBlock, 0);
        assertEq(p2pSupplyAmount, 0);
        assertEq(poolSupplyAmount, 0);
    }

    function testAverageBorrowRateShouldEqual0WhenNoBorrow() public {
        (uint256 borrowRatePerBlock, uint256 p2pBorrowAmount, uint256 poolBorrowAmount) =
            lens.getAverageBorrowRatePerBlock(vDai);

        assertEq(borrowRatePerBlock, 0);
        assertEq(p2pBorrowAmount, 0);
        assertEq(poolBorrowAmount, 0);
    }

    function testPoolSupplyAmountShouldBeEqualToPoolAmount() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 1_000_000);

        (,, uint256 poolSupplyAmount) = lens.getAverageSupplyRatePerBlock(vDai);

        assertEq(poolSupplyAmount, IVToken(vDai).balanceOf(address(evoq)).mul(IVToken(vDai).exchangeRateCurrent()));
    }

    function testPoolBorrowAmountShouldBeEqualToPoolAmount() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1_000_000);

        (,, uint256 poolBorrowAmount) = lens.getAverageBorrowRatePerBlock(vDai);

        assertApproxEqAbs(poolBorrowAmount, IVToken(vDai).borrowBalanceCurrent(address(evoq)), 1e4);
    }

    function testAverageSupplyRateShouldEqualPoolRateWhenNoMatch() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        (uint256 supplyRatePerBlock, uint256 p2pSupplyAmount, uint256 poolSupplyAmount) =
            lens.getAverageSupplyRatePerBlock(vDai);

        assertApproxEqAbs(supplyRatePerBlock, IVToken(vDai).supplyRatePerBlock(), 1);
        assertApproxEqAbs(poolSupplyAmount, amount, 1e9);
        assertEq(p2pSupplyAmount, 0);
    }

    function testAverageBorrowRateShouldEqualPoolRateWhenNoMatch() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        (uint256 borrowRatePerBlock, uint256 p2pBorrowAmount, uint256 poolBorrowAmount) =
            lens.getAverageBorrowRatePerBlock(vDai);

        assertApproxEqAbs(borrowRatePerBlock, IVToken(vDai).borrowRatePerBlock(), 1);
        assertApproxEqAbs(poolBorrowAmount, amount, 1);
        assertEq(p2pBorrowAmount, 0);
    }

    function testAverageRatesShouldEqualP2PRatesWhenFullyMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(wBnb, amount);
        supplier1.supply(vBnb, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        (uint256 supplyRatePerBlock, uint256 p2pSupplyAmount, uint256 poolSupplyAmount) =
            lens.getAverageSupplyRatePerBlock(vDai);
        (uint256 borrowRatePerBlock, uint256 p2pBorrowAmount, uint256 poolBorrowAmount) =
            lens.getAverageBorrowRatePerBlock(vDai);
        (uint256 p2pSupplyRate, uint256 p2pBorrowRate,,) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(supplyRatePerBlock, p2pSupplyRate, 1, "unexpected supply rate");
        assertApproxEqAbs(borrowRatePerBlock, p2pBorrowRate, 1, "unexpected borrow rate");
        assertApproxEqAbs(poolSupplyAmount, poolBorrowAmount, 1e9);
        assertApproxEqAbs(poolBorrowAmount, 0, 1e9);
        assertEq(p2pSupplyAmount, p2pBorrowAmount);
        assertApproxEqAbs(p2pBorrowAmount, amount, 1e9);
    }

    function testAverageSupplyRateShouldEqualMidrateWhenHalfMatched() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount / 2);

        (uint256 supplyRatePerBlock,,) = lens.getAverageSupplyRatePerBlock(vDai);
        (uint256 p2pSupplyRate,, uint256 poolSupplyRate,) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(supplyRatePerBlock, (p2pSupplyRate + poolSupplyRate) / 2, 1);
    }

    function testAverageBorrowRateShouldEqualMidrateWhenHalfMatched() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount / 2);
        supplier1.supply(vDai, amount / 2);

        (uint256 borrowRatePerBlock,,) = lens.getAverageBorrowRatePerBlock(vDai);
        (, uint256 p2pBorrowRate,, uint256 poolBorrowRate) = lens.getRatesPerBlock(vDai);

        assertApproxEqAbs(borrowRatePerBlock, (p2pBorrowRate + poolBorrowRate) / 2, 1);
    }

    function testAverageSupplyRateShouldEqualPoolRateWithFullSupplyDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vUsdc, (amount));

        supplier1.approve(usdc, (amount));
        supplier1.supply(vUsdc, (amount));

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        borrower1.approve(usdc, type(uint256).max);
        borrower1.repay(vUsdc, type(uint256).max);

        (uint256 avgSupplyRate,,) = lens.getAverageSupplyRatePerBlock(vUsdc);
        uint256 poolSupplyRate = IVToken(vUsdc).supplyRatePerBlock();

        assertApproxEqAbs(avgSupplyRate, poolSupplyRate, 2);
    }

    function testAverageBorrowRateShouldEqualPoolRateWithFullBorrowDelta() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, amount);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        supplier1.approve(dai, amount);
        supplier1.supply(vDai, amount);

        setDefaultMaxGasForMatchingHelper(3e6, 3e6, 0, 0);

        hevm.roll(block.number + 100);

        supplier1.withdraw(vDai, type(uint256).max);

        (uint256 avgBorrowRate,,) = lens.getAverageBorrowRatePerBlock(vDai);
        uint256 poolBorrowRate = IVToken(vDai).borrowRatePerBlock();

        assertApproxEqAbs(avgBorrowRate, poolBorrowRate, 1);
    }
}
