// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestGovernance is TestSetup {
    using CompoundMath for uint256;

    function testShouldDeployContractWithTheRightValues() public {
        assertEq(evoq.p2pSupplyIndex(vUsdt), 2 * 10 ** (16 + ERC20(IVToken(vUsdt).underlying()).decimals() - 8));
        assertEq(evoq.p2pBorrowIndex(vUsdt), 2 * 10 ** (16 + ERC20(IVToken(vUsdt).underlying()).decimals() - 8));
    }

    function testShouldRevertWhenCreatingMarketWithAnImproperMarket() public {
        Types.MarketParameters memory marketParams = Types.MarketParameters(3_333, 0);

        hevm.expectRevert("market not listed");
        evoq.createMarket(address(supplier1), marketParams);
    }

    function testOnlyOwnerCanCreateMarkets() public {
        Types.MarketParameters memory marketParams = Types.MarketParameters(3_333, 0);

        for (uint256 i = 0; i < pools.length; i++) {
            hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
            supplier1.createMarket(pools[i], marketParams);

            hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(borrower1)));
            borrower1.createMarket(pools[i], marketParams);
        }

        evoq.createMarket(vCake, marketParams);
    }

    function testShouldCreateMarketWithRightParams() public {
        Types.MarketParameters memory rightParams = Types.MarketParameters(1_000, 3_333);
        Types.MarketParameters memory wrongParams1 = Types.MarketParameters(10_001, 0);
        Types.MarketParameters memory wrongParams2 = Types.MarketParameters(0, 10_001);

        hevm.expectRevert(abi.encodeWithSignature("ExceedsMaxBasisPoints()"));
        evoq.createMarket(vCake, wrongParams1);
        hevm.expectRevert(abi.encodeWithSignature("ExceedsMaxBasisPoints()"));
        evoq.createMarket(vCake, wrongParams2);

        evoq.createMarket(vCake, rightParams);
        (uint16 reserveFactor, uint256 p2pIndexCursor) = evoq.marketParameters(vCake);
        assertEq(reserveFactor, 1_000);
        assertEq(p2pIndexCursor, 3_333);
    }

    function testOnlyOwnerCanSetReserveFactor() public {
        for (uint256 i = 0; i < pools.length; i++) {
            hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
            supplier1.setReserveFactor(vUsdt, 1111);

            hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(borrower1)));
            borrower1.setReserveFactor(vUsdt, 1111);
        }

        evoq.setReserveFactor(vUsdt, 1111);
    }

    function testReserveFactorShouldBeUpdatedWithRightValue() public {
        evoq.setReserveFactor(vUsdt, 1111);
        (uint16 reserveFactor,) = evoq.marketParameters(vUsdt);
        assertEq(reserveFactor, 1111);
    }

    function testShouldCreateMarketWithTheRightValues() public {
        IVToken vToken = IVToken(vCake);
        Types.MarketParameters memory marketParams = Types.MarketParameters(3_333, 0);
        evoq.createMarket(vCake, marketParams);

        (bool isCreated) = evoq.marketStatus(vCake);

        assertTrue(isCreated);
        assertEq(evoq.p2pSupplyIndex(vCake), 2 * 10 ** (16 + ERC20(vToken.underlying()).decimals() - 8));
        assertEq(evoq.p2pBorrowIndex(vCake), 2 * 10 ** (16 + ERC20(vToken.underlying()).decimals() - 8));
    }

    function testShouldSetMaxGasWithRightValues() public {
        Types.MaxGasForMatching memory newMaxGas =
            Types.MaxGasForMatching({supply: 1, borrow: 1, withdraw: 1, repay: 1});

        evoq.setDefaultMaxGasForMatching(newMaxGas);
        (uint64 supply, uint64 borrow, uint64 withdraw, uint64 repay) = evoq.defaultMaxGasForMatching();
        assertEq(supply, newMaxGas.supply);
        assertEq(borrow, newMaxGas.borrow);
        assertEq(withdraw, newMaxGas.withdraw);
        assertEq(repay, newMaxGas.repay);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setDefaultMaxGasForMatching(newMaxGas);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(borrower1)));
        borrower1.setDefaultMaxGasForMatching(newMaxGas);
    }

    function testOnlyOwnerCanSetMaxSortedUsers() public {
        uint256 newMaxSortedUsers = 30;

        evoq.setMaxSortedUsers(newMaxSortedUsers);
        assertEq(evoq.maxSortedUsers(), newMaxSortedUsers);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setMaxSortedUsers(newMaxSortedUsers);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(borrower1)));
        borrower1.setMaxSortedUsers(newMaxSortedUsers);
    }

    function testOnlyOwnerShouldFlipMarketStrategy() public {
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsP2PDisabled(vUsdt, true);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier2)));
        supplier2.setIsP2PDisabled(vUsdt, true);

        evoq.setIsP2PDisabled(vUsdt, true);
        assertTrue(evoq.p2pDisabled(vUsdt));
    }

    function testOnlyOwnerShouldSetPositionsManager() public {
        IPositionsManager positionsManagerV2 = new PositionsManager();

        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setPositionsManager(positionsManagerV2);

        evoq.setPositionsManager(positionsManagerV2);
        assertEq(address(evoq.positionsManager()), address(positionsManagerV2));
    }

    function testOnlyOwnerShouldSetRewardsManager() public {
        IRewardsManager rewardsManagerV2 = new RewardsManager();

        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setRewardsManager(rewardsManagerV2);

        evoq.setRewardsManager(rewardsManagerV2);
        assertEq(address(evoq.rewardsManager()), address(rewardsManagerV2));
    }

    function testOnlyOwnerShouldSetInterestRatesManager() public {
        IInterestRatesManager interestRatesV2 = new InterestRatesManager();

        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setInterestRatesManager(interestRatesV2);

        evoq.setInterestRatesManager(interestRatesV2);
        assertEq(address(evoq.interestRatesManager()), address(interestRatesV2));
    }

    function testOnlyOwnerShouldSetDustThreshold() public {
        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setDustThreshold(1e8);

        evoq.setDustThreshold(1e8);
        assertEq(evoq.dustThreshold(), 1e8);
    }

    function testOnlyOwnerShouldSetTreasuryVault() public {
        address treasuryVaultV2 = address(2);

        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setTreasuryVault(treasuryVaultV2);

        evoq.setTreasuryVault(treasuryVaultV2);
        assertEq(address(evoq.treasuryVault()), treasuryVaultV2);
    }

    function testOnlyOwnerCanSetIsClaimRewardsPaused() public {
        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setIsClaimRewardsPaused(true);

        evoq.setIsClaimRewardsPaused(true);
        assertTrue(evoq.isClaimRewardsPaused());
    }

    function testSetP2PIndexCursor() public {
        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setP2PIndexCursor(vUsdt, 5000);

        hevm.expectRevert(abi.encodeWithSignature("ExceedsMaxBasisPoints()"));
        evoq.setP2PIndexCursor(vUsdt, 10001);

        evoq.setP2PIndexCursor(vUsdt, 6969);
        (, uint16 p2pIndexCursor) = evoq.marketParameters(vUsdt);
        assertEq(p2pIndexCursor, 6969);
    }

    function testOnlyOwnerShouldSetDeprecatedMarket() public {
        evoq.setIsBorrowPaused(vUsdt, true);

        hevm.prank(address(supplier1));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        evoq.setIsDeprecated(vUsdt, true);

        hevm.prank(address(supplier2));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier2)));
        evoq.setIsDeprecated(vUsdt, true);

        evoq.setIsDeprecated(vUsdt, true);
        (,,,,,, bool isDeprecated) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isDeprecated);

        evoq.setIsDeprecated(vUsdt, false);
        (,,,,,, isDeprecated) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isDeprecated);
    }

    function testOnlyOwnerShouldDisableSupply() public {
        (bool isSupplyPaused,,,,,,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isSupplyPaused);

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsSupplyPaused(vUsdt, true);

        evoq.setIsSupplyPaused(vUsdt, true);
        (isSupplyPaused,,,,,,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isSupplyPaused);
    }

    function testOnlyOwnerShouldDisableBorrow() public {
        (, bool isBorrowPaused,,,,,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isBorrowPaused);
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsBorrowPaused(vUsdt, true);

        evoq.setIsBorrowPaused(vUsdt, true);
        (, isBorrowPaused,,,,,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isBorrowPaused);
    }

    function testOnlyOwnerShouldDisableWithdraw() public {
        (,, bool isWithdrawPaused,,,,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isWithdrawPaused);
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsWithdrawPaused(vUsdt, true);

        evoq.setIsWithdrawPaused(vUsdt, true);
        (,, isWithdrawPaused,,,,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isWithdrawPaused);
    }

    function testOnlyOwnerShouldDisableRepay() public {
        (,,, bool isRepayPaused,,,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isRepayPaused);
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsRepayPaused(vUsdt, true);

        evoq.setIsRepayPaused(vUsdt, true);
        (,,, isRepayPaused,,,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isRepayPaused);
    }

    function testOnlyOwnerShouldDisableLiquidateOnCollateral() public {
        (,,,, bool isLiquidateCollateralPaused,,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isLiquidateCollateralPaused);
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsLiquidateCollateralPaused(vUsdt, true);

        evoq.setIsLiquidateCollateralPaused(vUsdt, true);
        (,,,, isLiquidateCollateralPaused,,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isLiquidateCollateralPaused);
    }

    function testOnlyOwnerShouldDisableLiquidateOnBorrow() public {
        (,,,,, bool isLiquidateBorrowPaused,) = evoq.marketPauseStatus(vUsdt);
        assertFalse(isLiquidateBorrowPaused);
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsLiquidateBorrowPaused(vUsdt, true);

        evoq.setIsLiquidateBorrowPaused(vUsdt, true);
        (,,,,, isLiquidateBorrowPaused,) = evoq.marketPauseStatus(vUsdt);
        assertTrue(isLiquidateBorrowPaused);
    }

    function testOnlyOwnerCanIncreaseP2PDeltas() public {
        hevm.prank(address(supplier1));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        evoq.increaseP2PDeltas(vUsdt, 0);

        supplier1.approve(usdt, type(uint256).max);
        supplier1.supply(vUsdt, 1_000 ether);
        supplier1.borrow(vUsdt, 2 ether);

        evoq.increaseP2PDeltas(vUsdt, 1 ether);
    }

    function testShouldNotIncreaseP2PDeltasWhenMarketNotCreated() public {
        hevm.expectRevert(abi.encodeWithSignature("MarketNotCreated()"));
        evoq.increaseP2PDeltas(address(1), 0);
    }

    function testIncreaseP2PDeltas() public {
        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 increaseDeltaAmount = 30 ether;

        supplier1.approve(wBnb, supplyAmount);
        supplier1.supply(vBnb, supplyAmount);
        supplier1.approve(usdt, supplyAmount);
        supplier1.supply(vUsdt, supplyAmount);
        supplier1.borrow(vUsdt, borrowAmount);

        evoq.increaseP2PDeltas(vUsdt, increaseDeltaAmount);

        (uint256 p2pSupplyDelta, uint256 p2pBorrowDelta,,) = evoq.deltas(vUsdt);

        assertEq(p2pSupplyDelta, increaseDeltaAmount.div(IVToken(vUsdt).exchangeRateStored()));
        assertEq(p2pBorrowDelta, increaseDeltaAmount.div(IVToken(vUsdt).borrowIndex()));
        assertApproxEqRel(
            IVToken(vUsdt).balanceOfUnderlying(address(evoq)), supplyAmount - borrowAmount + increaseDeltaAmount, 1e8
        );
        assertApproxEqRel(IVToken(vUsdt).borrowBalanceCurrent(address(evoq)), increaseDeltaAmount, 1e8);
    }

    function testIncreaseP2PDeltasMoreThanWhatIsPossibleSupply() public {
        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 deltaAmount = 25 ether;
        uint256 increaseDeltaAmount = 80 ether;

        supplier1.approve(wBnb, type(uint256).max);
        supplier1.supply(vBnb, supplyAmount);
        supplier1.approve(usdt, type(uint256).max);
        supplier1.supply(vUsdt, supplyAmount);
        supplier1.borrow(vUsdt, borrowAmount);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        hevm.roll(block.number + 1);
        supplier1.repay(vUsdt, deltaAmount); // Creates a peer-to-peer supply delta.

        evoq.increaseP2PDeltas(vUsdt, increaseDeltaAmount);

        (uint256 p2pSupplyDelta, uint256 p2pBorrowDelta,,) = evoq.deltas(vUsdt);

        assertApproxEqRel(p2pSupplyDelta, borrowAmount.div(IVToken(vUsdt).exchangeRateStored()), 1e12);
        assertApproxEqRel(p2pBorrowDelta, (borrowAmount - deltaAmount).div(IVToken(vUsdt).borrowIndex()), 1e12);
        assertApproxEqRel(IVToken(vUsdt).balanceOfUnderlying(address(evoq)), supplyAmount, 1e12);
        assertApproxEqRel(IVToken(vUsdt).borrowBalanceCurrent(address(evoq)), borrowAmount - deltaAmount, 1e12);
    }

    function testIncreaseP2PDeltasMoreThanWhatIsPossibleBorrow() public {
        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 deltaAmount = 25 ether;
        uint256 increaseDeltaAmount = 80 ether;

        supplier1.approve(wBnb, supplyAmount);
        supplier1.supply(vBnb, supplyAmount);
        supplier1.approve(usdt, supplyAmount);
        supplier1.supply(vUsdt, supplyAmount);
        supplier1.borrow(vUsdt, borrowAmount);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        supplier1.withdraw(vUsdt, supplyAmount - borrowAmount + deltaAmount); // Creates a peer-to-peer borrow delta.

        evoq.increaseP2PDeltas(vUsdt, increaseDeltaAmount);

        (uint256 p2pSupplyDelta, uint256 p2pBorrowDelta,,) = evoq.deltas(vUsdt);

        assertApproxEqRel(p2pSupplyDelta, (borrowAmount - deltaAmount).div(IVToken(vUsdt).exchangeRateStored()), 1e8);
        assertApproxEqRel(p2pBorrowDelta, borrowAmount.div(IVToken(vUsdt).borrowIndex()), 1e8);
        assertApproxEqRel(IVToken(vUsdt).balanceOfUnderlying(address(evoq)), deltaAmount, 1e8);
        assertApproxEqRel(IVToken(vUsdt).borrowBalanceCurrent(address(evoq)), borrowAmount, 1e8);
    }

    function testIncreaseP2PDeltasWithMaxBorrowDelta() public {
        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 increaseDeltaAmount = 80 ether;

        supplier1.approve(wBnb, supplyAmount);
        supplier1.supply(vBnb, supplyAmount);
        supplier1.approve(usdt, supplyAmount);
        supplier1.supply(vUsdt, supplyAmount);
        supplier1.borrow(vUsdt, borrowAmount);
        setDefaultMaxGasForMatchingHelper(0, 0, 0, 0);
        supplier1.withdraw(vUsdt, type(uint256).max); // Creates a 100% peer-to-peer borrow delta.

        hevm.roll(block.number + 1000);

        hevm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        evoq.increaseP2PDeltas(vUsdt, increaseDeltaAmount);
    }

    function testFailCallIncreaseP2PDeltasFromImplementation() public {
        positionsManager.increaseP2PDeltasLogic(vUsdt, 0);
    }

    function testDeprecateCycle() public {
        hevm.expectRevert(abi.encodeWithSignature("BorrowNotPaused()"));
        evoq.setIsDeprecated(vUsdt, true);

        evoq.setIsBorrowPaused(vUsdt, true);
        evoq.setIsDeprecated(vUsdt, true);

        hevm.expectRevert(abi.encodeWithSignature("MarketIsDeprecated()"));
        evoq.setIsBorrowPaused(vUsdt, false);

        evoq.setIsDeprecated(vUsdt, false);
        evoq.setIsBorrowPaused(vUsdt, false);
    }
}
