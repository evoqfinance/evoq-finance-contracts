// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestRewards is TestSetup {
    function testShouldClaimRightAmountOfSupplyRewards() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        uint256 balanceBefore = supplier1.balanceOf(xvs);

        (, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        uint256 userIndex = rewardsManager.venusSupplierIndex(vDai, address(supplier1));
        address[] memory vTokens = new address[](1);
        vTokens[0] = vDai;
        uint256 unclaimedRewards = lens.getUserUnclaimedRewards(vTokens, address(supplier1));

        uint256 index = comptroller.venusSupplyState(vDai).index;

        testEquality(userIndex, index, "user index wrong");
        assertEq(unclaimedRewards, 0, "unclaimed rewards should be 0");

        supplier2.approve(dai, toSupply);
        supplier2.supply(vDai, toSupply);

        hevm.roll(block.number + 1_000);
        uint256 claimedAmount = supplier1.claimRewards(vTokens);

        index = comptroller.venusSupplyState(vDai).index;

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;
        uint256 balanceAfter = supplier1.balanceOf(xvs);
        uint256 expectedNewBalance = expectedClaimed + balanceBefore;

        assertEq(claimedAmount, expectedClaimed, "unexpected claimed amount");
        testEquality(balanceAfter, expectedNewBalance, "balance after wrong");
    }

    function testShouldRevertWhenClaimRewardsIsPaused() public {
        address[] memory vDaiInArray = new address[](1);
        vDaiInArray[0] = vDai;

        evoq.setIsClaimRewardsPaused(true);

        hevm.expectRevert(abi.encodeWithSignature("ClaimRewardsPaused()"));
        evoq.claimRewards(vDaiInArray);
    }

    function testShouldGetRightAmountOfSupplyRewards() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);

        uint256 index = comptroller.venusSupplyState(vDai).index;

        (, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        uint256 userIndex = rewardsManager.venusSupplierIndex(vDai, address(supplier1));
        address[] memory vTokens = new address[](1);
        vTokens[0] = vDai;
        uint256 unclaimedRewards = lens.getUserUnclaimedRewards(vTokens, address(supplier1));

        testEquality(index, userIndex, "user index wrong");
        assertEq(unclaimedRewards, 0, "unclaimed rewards should be 0");

        supplier2.approve(dai, toSupply);
        supplier2.supply(vDai, toSupply);

        hevm.roll(block.number + 1_000);
        unclaimedRewards = lens.getUserUnclaimedRewards(vTokens, address(supplier1));

        uint256 claimedAmount = supplier1.claimRewards(vTokens);
        index = comptroller.venusSupplyState(vDai).index;

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;
        assertEq(claimedAmount, expectedClaimed, "unexpected claimed amount");
        testEquality(unclaimedRewards, expectedClaimed);
    }

    function testShouldClaimRightAmountOfBorrowRewards() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.borrow(vUsdc, (50 ether));

        uint256 index = comptroller.venusBorrowState(vUsdc).index;

        (, uint256 onPool) = evoq.borrowBalanceInOf(vUsdc, address(supplier1));
        uint256 userIndex = rewardsManager.venusBorrowerIndex(vUsdc, address(supplier1));
        address[] memory vTokens = new address[](1);
        vTokens[0] = vUsdc;
        hevm.prank(address(evoq));
        uint256 unclaimedRewards = rewardsManager.claimRewards(vTokens, address(supplier1));

        testEquality(userIndex, index, "user index wrong");
        assertEq(unclaimedRewards, 0, "unclaimed rewards should be 0");

        hevm.roll(block.number + 1_000);
        uint256 claimedAmount = supplier1.claimRewards(vTokens);

        index = comptroller.venusBorrowState(vUsdc).index;

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;
        uint256 balanceAfter = supplier1.balanceOf(xvs);

        assertEq(claimedAmount, expectedClaimed, "unexpected claimed amount");
        testEquality(balanceAfter, expectedClaimed, "balance after wrong");
    }

    function testShouldGetRightAmountOfBorrowRewards() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.borrow(vUsdc, (50 ether));

        uint256 index = comptroller.venusBorrowState(vUsdc).index;

        (, uint256 onPool) = evoq.borrowBalanceInOf(vUsdc, address(supplier1));
        uint256 userIndex = rewardsManager.venusBorrowerIndex(vUsdc, address(supplier1));
        address[] memory vTokens = new address[](1);
        vTokens[0] = vUsdc;
        uint256 unclaimedRewards = lens.getUserUnclaimedRewards(vTokens, address(supplier1));

        testEquality(index, userIndex, "user index wrong");
        assertEq(unclaimedRewards, 0, "unclaimed rewards should be 0");

        hevm.roll(block.number + 1_000);

        unclaimedRewards = lens.getUserUnclaimedRewards(vTokens, address(supplier1));

        uint256 claimedAmount = supplier1.claimRewards(vTokens);
        index = comptroller.venusBorrowState(vUsdc).index;

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;
        assertEq(claimedAmount, expectedClaimed, "unexpected claimed amount");
        testEquality(unclaimedRewards, expectedClaimed);
    }

    function testShouldClaimOnSeveralMarkets() public {
        uint256 toSupply = 100 ether;
        uint256 toBorrow = 50 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.borrow(vUsdc, toBorrow);
        uint256 rewardBalanceBefore = supplier1.balanceOf(xvs);

        hevm.roll(block.number + 1_000);

        address[] memory vTokens = new address[](1);
        vTokens[0] = vDai;
        supplier1.claimRewards(vTokens);
        uint256 rewardBalanceAfter1 = supplier1.balanceOf(xvs);
        // assertGt(rewardBalanceAfter1, rewardBalanceBefore); // XVS is no longer rewarded.

        address[] memory debtUsdcInArray = new address[](1);
        debtUsdcInArray[0] = vUsdc;
        supplier1.claimRewards(debtUsdcInArray);
        uint256 rewardBalanceAfter2 = supplier1.balanceOf(xvs);
        // assertGt(rewardBalanceAfter2, rewardBalanceAfter1); // XVS is no longer rewarded.
    }

    function testShouldNotBePossibleToClaimRewardsOnOtherMarket() public {
        uint256 toSupply = 100 ether;
        uint256 toSupply2 = 50 ether;

        uint256 balanceBefore = supplier1.balanceOf(xvs);
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier2.approve(usdc, toSupply2);
        supplier2.supply(vUsdc, toSupply2);

        hevm.roll(block.number + 1_000);

        address[] memory vTokens = new address[](1);
        vTokens[0] = vUsdc;

        assertEq(supplier1.claimRewards(vTokens), 0);

        uint256 balanceAfter = supplier1.balanceOf(xvs);
        assertEq(balanceAfter, balanceBefore);
    }

    function testShouldClaimRewardsOnSeveralMarketsAtOnce() public {
        uint256 toSupply = 100 ether;
        uint256 toBorrow = 50 ether;
        supplier1.approve(dai, toSupply);
        supplier1.approve(wBnb, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.supply(vBnb, toSupply);
        supplier1.borrow(vUsdc, toBorrow);

        hevm.roll(block.number + 1_000_000);

        address[] memory daiInArray = new address[](1);
        daiInArray[0] = vDai;

        address[] memory tokensInArray = new address[](3);
        tokensInArray[0] = vDai;
        tokensInArray[1] = vBnb;
        tokensInArray[2] = vUsdc;

        uint256 unclaimedRewardsForDaiView = lens.getUserUnclaimedRewards(daiInArray, address(supplier1));
        // assertGt(unclaimedRewardsForDaiView, 0); // XVS is no longer rewarded.

        uint256 allUnclaimedRewardsView = lens.getUserUnclaimedRewards(tokensInArray, address(supplier1));
        // assertGt(allUnclaimedRewardsView, 0); // XVS is no longer rewarded.

        hevm.prank(address(evoq));
        uint256 allUnclaimedRewards = rewardsManager.claimRewards(tokensInArray, address(supplier1));
        assertEq(allUnclaimedRewards, allUnclaimedRewards, "wrong rewards amount");

        allUnclaimedRewardsView = lens.getUserUnclaimedRewards(tokensInArray, address(supplier1));
        assertEq(allUnclaimedRewardsView, 0, "unclaimed rewards not null");

        hevm.prank(address(evoq));
        allUnclaimedRewards = rewardsManager.claimRewards(tokensInArray, address(supplier1));
        assertEq(allUnclaimedRewards, 0);
    }

    function testUsersShouldClaimRewardsIndependently() public {
        interactWithVenus();
        interactWithEvoq();

        uint256[4] memory balanceBefore;
        balanceBefore[1] = ERC20(xvs).balanceOf(address(supplier1));
        balanceBefore[2] = ERC20(xvs).balanceOf(address(supplier2));
        balanceBefore[3] = ERC20(xvs).balanceOf(address(supplier3));

        hevm.roll(block.number + 1_000);

        address[] memory tokensInArray = new address[](2);
        tokensInArray[0] = vDai;
        tokensInArray[1] = vUsdc;
        supplier1.claimRewards(tokensInArray);
        supplier2.claimRewards(tokensInArray);
        supplier3.claimRewards(tokensInArray);

        uint256[4] memory balanceAfter;
        balanceAfter[1] = ERC20(xvs).balanceOf(address(supplier1));
        balanceAfter[2] = ERC20(xvs).balanceOf(address(supplier2));
        balanceAfter[3] = ERC20(xvs).balanceOf(address(supplier3));

        supplier1.venusClaimRewards(tokensInArray);
        supplier2.venusClaimRewards(tokensInArray);
        supplier3.venusClaimRewards(tokensInArray);

        uint256[4] memory balanceAfterVenus;
        balanceAfterVenus[1] = ERC20(xvs).balanceOf(address(supplier1));
        balanceAfterVenus[2] = ERC20(xvs).balanceOf(address(supplier2));
        balanceAfterVenus[3] = ERC20(xvs).balanceOf(address(supplier3));

        uint256[4] memory claimedFromVenus;
        claimedFromVenus[1] = balanceAfterVenus[1] - balanceAfter[1];
        claimedFromVenus[2] = balanceAfterVenus[2] - balanceAfter[2];
        claimedFromVenus[3] = balanceAfterVenus[3] - balanceAfter[3];

        uint256[4] memory claimedFromEvoq;
        claimedFromEvoq[1] = balanceAfter[1];
        claimedFromEvoq[2] = balanceAfter[2];
        claimedFromEvoq[3] = balanceAfter[3];
        testEquality(claimedFromVenus[1], claimedFromEvoq[1], "claimed rewards 1");
        testEquality(claimedFromVenus[2], claimedFromEvoq[2], "claimed rewards 2");
        testEquality(claimedFromVenus[3], claimedFromEvoq[3], "claimed rewards 3");

        // XVS is no longer rewarded.
        // assertGt(balanceAfter[1], balanceBefore[1]);
        // assertGt(balanceAfter[2], balanceBefore[2]);
        // assertGt(balanceAfter[3], balanceBefore[3]);

        hevm.prank(address(evoq));
        uint256 unclaimedRewards1 = rewardsManager.claimRewards(tokensInArray, address(supplier1));
        hevm.prank(address(evoq));
        uint256 unclaimedRewards2 = rewardsManager.claimRewards(tokensInArray, address(supplier2));
        hevm.prank(address(evoq));
        uint256 unclaimedRewards3 = rewardsManager.claimRewards(tokensInArray, address(supplier3));

        assertEq(unclaimedRewards1, 0);
        assertEq(unclaimedRewards2, 0);
        assertEq(unclaimedRewards3, 0);
    }

    function interactWithVenus() internal {
        uint256 toSupply = 100 ether;
        uint256 toBorrow = 50 ether;

        supplier1.venusSupply(vDai, toSupply);
        supplier1.venusBorrow(vUsdc, toBorrow);
        supplier2.venusSupply(vDai, toSupply);
        supplier2.venusBorrow(vUsdc, toBorrow);
        supplier3.venusSupply(vDai, toSupply);
        supplier3.venusBorrow(vUsdc, toBorrow);
    }

    function interactWithEvoq() internal {
        uint256 toSupply = 100 ether;
        uint256 toBorrow = 50 ether;

        supplier1.approve(dai, toSupply);
        supplier2.approve(dai, toSupply);
        supplier3.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.borrow(vUsdc, toBorrow);
        supplier2.supply(vDai, toSupply);
        supplier2.borrow(vUsdc, toBorrow);
        supplier3.supply(vDai, toSupply);
        supplier3.borrow(vUsdc, toBorrow);
    }

    function testShouldClaimTheSameAmountOfRewards() public {
        uint256 smallAmount = 1 ether;
        uint256 bigAmount = 10_000 ether;

        supplier1.approve(usdc, type(uint256).max);
        supplier1.supply(vUsdc, (smallAmount));
        supplier2.approve(usdc, type(uint256).max);
        supplier2.supply(vUsdc, (smallAmount));

        move100BlocksForward(vUsdc);

        address[] memory markets = new address[](1);
        markets[0] = vUsdc;

        hevm.prank(address(evoq));
        rewardsManager.claimRewards(markets, address(supplier1));

        // supplier2 tries to game the system by supplying a huge amount of tokens and withdrawing right after accruing its rewards.
        supplier2.supply(vUsdc, (bigAmount));
        hevm.prank(address(evoq));
        rewardsManager.claimRewards(markets, address(supplier2));
        supplier2.withdraw(vUsdc, (bigAmount));

        assertEq(
            lens.getUserUnclaimedRewards(markets, address(supplier1)),
            lens.getUserUnclaimedRewards(markets, address(supplier2))
        );
    }

    function testFailShouldNotClaimRewardsWhenRewardsManagerIsAddressZero() public {
        uint256 amount = 1 ether;

        supplier1.approve(usdc, type(uint256).max);
        supplier1.supply(vUsdc, (amount));

        // Set RewardsManager to address(0).
        evoq.setRewardsManager(IRewardsManager(address(0)));

        move1000BlocksForward(vUsdc);

        address[] memory markets = new address[](1);
        markets[0] = vUsdc;

        // User accrues its rewards.
        hevm.prank(address(evoq));
        rewardsManager.claimRewards(markets, address(supplier1));

        // User tries to claim its rewards on Evoq.
        supplier1.claimRewards(markets);
    }

    function testShouldUpdateCorrectSupplyIndex() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 5_000);
        supplier1.approve(dai, vDai, type(uint256).max);
        supplier1.venusSupply(vDai, amount);
        hevm.roll(block.number + 5_000);

        supplier1.borrow(vDai, amount / 2);

        uint256 userIndexAfter = rewardsManager.venusSupplierIndex(vDai, address(supplier1));
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusSupplyState(vDai);

        assertEq(userIndexAfter, venusAfter.index);
    }

    function testShouldUpdateCorrectSupplyIndexWhenSpeedIs0() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 1);
        hevm.prank(comptroller.admin());
        IVToken[] memory vTokens = new IVToken[](1);
        uint256[] memory supplySpeeds = new uint256[](1);
        uint256[] memory borrowSpeeds = new uint256[](1);
        vTokens[0] = IVToken(vDai);
        comptroller._setVenusSpeeds(vTokens, supplySpeeds, borrowSpeeds);
        hevm.roll(block.number + 1);

        supplier1.borrow(vDai, amount / 2);

        uint256 userIndexAfter = rewardsManager.venusSupplierIndex(vDai, address(supplier1));
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusSupplyState(vDai);

        assertEq(userIndexAfter, venusAfter.index);
    }

    function testShouldUpdateCorrectBorrowIndex() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, type(uint256).max);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 5_000);
        borrower1.approve(dai, vDai, type(uint256).max);
        borrower1.venusSupply(vDai, amount);
        borrower1.venusBorrow(vDai, amount / 2);
        hevm.roll(block.number + 5_000);

        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, amount / 2);

        uint256 userIndexAfter = rewardsManager.venusBorrowerIndex(vDai, address(borrower1));
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusBorrowState(vDai);

        assertEq(userIndexAfter, venusAfter.index);
    }

    function testShouldUpdateCorrectBorrowIndexWhenSpeedIs0() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, type(uint256).max);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 1);
        hevm.prank(comptroller.admin());
        IVToken[] memory vTokens = new IVToken[](1);
        uint256[] memory supplySpeeds = new uint256[](1);
        uint256[] memory borrowSpeeds = new uint256[](1);
        vTokens[0] = IVToken(vDai);
        comptroller._setVenusSpeeds(vTokens, supplySpeeds, borrowSpeeds);
        hevm.roll(block.number + 1);

        borrower1.approve(dai, type(uint256).max);
        borrower1.supply(vDai, amount / 2);

        uint256 userIndexAfter = rewardsManager.venusBorrowerIndex(vDai, address(borrower1));
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusBorrowState(vDai);

        assertEq(userIndexAfter, venusAfter.index);
    }

    function testShouldComputeCorrectSupplyIndex() public {
        uint256 amount = 10_000 ether;

        supplier1.approve(dai, type(uint256).max);
        supplier1.supply(vDai, amount);

        hevm.roll(block.number + 5_000);
        supplier1.approve(dai, vDai, type(uint256).max);
        supplier1.venusSupply(vDai, amount);
        hevm.roll(block.number + 5_000);

        uint256 updatedIndex = lens.getCurrentXvsSupplyIndex(vDai);

        supplier1.venusSupply(vDai, amount / 10); // Update venusSupplyState.
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusSupplyState(vDai);

        assertEq(updatedIndex, venusAfter.index);
    }

    function testShouldComputeCorrectBorrowIndex() public {
        uint256 amount = 10_000 ether;

        borrower1.approve(wBnb, type(uint256).max);
        borrower1.supply(vBnb, amount);
        borrower1.borrow(vDai, amount);

        hevm.roll(block.number + 5_000);
        borrower1.approve(dai, vDai, type(uint256).max);
        borrower1.venusSupply(vDai, amount);
        borrower1.venusBorrow(vDai, amount / 2);
        hevm.roll(block.number + 5_000);

        IVToken(vDai).accrueInterest();
        uint256 updatedIndex = lens.getCurrentXvsBorrowIndex(vDai);

        borrower1.venusBorrow(vDai, amount / 10); // Update venusBorrowState.
        IComptroller.VenusMarketState memory venusAfter = comptroller.venusBorrowState(vDai);

        assertEq(updatedIndex, venusAfter.index);
    }

    function testShouldAllowClaimingRewardsOfMarketAlreadyClaimed() public {
        uint256 amount = (1 ether);
        address[] memory vUsdcArray = new address[](1);
        vUsdcArray[0] = vUsdc;
        address[] memory vUsdtArray = new address[](1);
        vUsdtArray[0] = vUsdt;

        supplier1.approve(usdc, type(uint256).max);
        supplier1.supply(vUsdc, amount);
        supplier2.approve(usdc, type(uint256).max);
        supplier2.supply(vUsdc, amount);
        supplier3.approve(usdt, type(uint256).max);
        supplier3.supply(vUsdt, amount / 2);

        hevm.roll(block.number + 100_000);

        supplier1.claimRewards(vUsdcArray);
        supplier3.claimRewards(vUsdtArray);
        supplier2.claimRewards(vUsdcArray);
    }

    function testGetAccruedSupplyComp() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);

        hevm.roll(block.number + 1_000);

        (, uint256 onPool) = evoq.supplyBalanceInOf(vDai, address(supplier1));
        uint256 userIndex = rewardsManager.venusSupplierIndex(vDai, address(supplier1));
        uint256 unclaimedRewards1 = lens.getAccruedSupplierXvs(address(supplier1), vDai);
        uint256 unclaimedRewards2 = lens.getAccruedSupplierXvs(address(supplier1), vDai, onPool);
        uint256 index = lens.getCurrentXvsSupplyIndex(vDai);

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;

        // XVS is no longer rewarded.
        // assertGt(unclaimedRewards1, 0);
        assertEq(unclaimedRewards1, unclaimedRewards2, "not same supply accrued amt");
        assertEq(unclaimedRewards1, expectedClaimed, "unexpected supply accrued amount");
    }

    function testGetAccruedBorrowComp() public {
        uint256 toSupply = 100 ether;
        supplier1.approve(dai, toSupply);
        supplier1.supply(vDai, toSupply);
        supplier1.borrow(vUsdc, (50 ether));

        hevm.roll(block.number + 1_000);

        (, uint256 onPool) = evoq.borrowBalanceInOf(vUsdc, address(supplier1));
        uint256 userIndex = rewardsManager.venusBorrowerIndex(vUsdc, address(supplier1));
        uint256 unclaimedRewards1 = lens.getAccruedBorrowerXvs(address(supplier1), vUsdc);
        uint256 unclaimedRewards2 = lens.getAccruedBorrowerXvs(address(supplier1), vUsdc, onPool);
        uint256 index = lens.getCurrentXvsBorrowIndex(vUsdc);

        uint256 expectedClaimed = (onPool * (index - userIndex)) / 1e36;

        // XVS is no longer rewarded.
        // assertGt(unclaimedRewards1, 0);
        assertEq(unclaimedRewards1, unclaimedRewards2, "not same borrow accrued amt");
        assertEq(unclaimedRewards1, expectedClaimed, "unexpected borrow accrued amount");
    }
}
