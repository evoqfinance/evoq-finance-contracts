// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestPausableMarket is TestSetup {
    using CompoundMath for uint256;

    address[] public vBnbArray = [vBnb];
    address[] public vDaiArray = [vDai];
    uint256[] public amountArray = [1 ether];

    function testAllMarketsPauseUnpause() public {
        evoq.setIsPausedForAllMarkets(true);

        for (uint256 i; i < pools.length; ++i) {
            (
                bool isSupplyPaused,
                bool isBorrowPaused,
                bool isWithdrawPaused,
                bool isRepayPaused,
                bool isLiquidateCollateralPaused,
                bool isLiquidateBorrowPaused,
            ) = evoq.marketPauseStatus(pools[i]);
            assertTrue(isSupplyPaused);
            assertTrue(isBorrowPaused);
            assertTrue(isWithdrawPaused);
            assertTrue(isRepayPaused);
            assertTrue(isLiquidateCollateralPaused);
            assertTrue(isLiquidateBorrowPaused);
        }

        evoq.setIsPausedForAllMarkets(false);

        for (uint256 i; i < pools.length; ++i) {
            (
                bool isSupplyPaused,
                bool isBorrowPaused,
                bool isWithdrawPaused,
                bool isRepayPaused,
                bool isLiquidateCollateralPaused,
                bool isLiquidateBorrowPaused,
            ) = evoq.marketPauseStatus(pools[i]);
            assertFalse(isSupplyPaused);
            assertFalse(isBorrowPaused);
            assertFalse(isWithdrawPaused);
            assertFalse(isRepayPaused);
            assertFalse(isLiquidateCollateralPaused);
            assertFalse(isLiquidateBorrowPaused);
        }
    }

    function testShouldDisableAllMarketsWhenGloballyPaused() public {
        evoq.setIsPausedForAllMarkets(true);

        uint256 poolsLength = pools.length;
        for (uint256 i; i < poolsLength; ++i) {
            hevm.expectRevert(abi.encodeWithSignature("SupplyIsPaused()"));
            supplier1.supply(pools[i], 1);

            hevm.expectRevert(abi.encodeWithSignature("BorrowIsPaused()"));
            supplier1.borrow(pools[i], 1);

            hevm.expectRevert(abi.encodeWithSignature("WithdrawIsPaused()"));
            supplier1.withdraw(pools[i], 1);

            hevm.expectRevert(abi.encodeWithSignature("RepayIsPaused()"));
            supplier1.repay(pools[i], 1);

            hevm.expectRevert(abi.encodeWithSignature("LiquidateCollateralIsPaused()"));
            supplier1.liquidate(pools[i], pools[0], address(supplier1), 1);
        }
    }

    function testBorrowPauseCheckSkipped() public {
        // Deprecate a market.
        evoq.setIsBorrowPaused(vDai, true);
        evoq.setIsDeprecated(vDai, true);
        (, bool isBorrowPaused,,,,, bool isDeprecated) = evoq.marketPauseStatus(vDai);

        assertTrue(isBorrowPaused);
        assertTrue(isDeprecated);

        evoq.setIsPausedForAllMarkets(false);
        (, isBorrowPaused,,,,, isDeprecated) = evoq.marketPauseStatus(vDai);

        assertTrue(isBorrowPaused);
        assertTrue(isDeprecated);

        evoq.setIsPausedForAllMarkets(true);
        (, isBorrowPaused,,,,, isDeprecated) = evoq.marketPauseStatus(vDai);

        assertTrue(isBorrowPaused);
        assertTrue(isDeprecated);
    }

    function testOnlyOwnerShouldDisableSupply() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsSupplyPaused(vDai, true);

        evoq.setIsSupplyPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("SupplyIsPaused()"));
        supplier1.supply(vDai, amount);
    }

    function testOnlyOwnerShouldDisableBorrow() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsBorrowPaused(vDai, true);

        evoq.setIsBorrowPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("BorrowIsPaused()"));
        supplier1.borrow(vDai, amount);
    }

    function testOnlyOwnerShouldDisableWithdraw() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsWithdrawPaused(vDai, true);

        evoq.setIsWithdrawPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("WithdrawIsPaused()"));
        supplier1.withdraw(vDai, amount);
    }

    function testOnlyOwnerShouldDisableRepay() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsRepayPaused(vDai, true);

        evoq.setIsRepayPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("RepayIsPaused()"));
        supplier1.repay(vDai, amount);
    }

    function testOnlyOwnerShouldDisableLiquidateOnCollateral() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsLiquidateCollateralPaused(vDai, true);

        evoq.setIsLiquidateCollateralPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("LiquidateCollateralIsPaused()"));
        supplier1.liquidate(vUsdc, vDai, address(supplier2), amount);
    }

    function testOnlyOwnerShouldDisableLiquidateOnBorrow() public {
        uint256 amount = 10_000 ether;

        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
        supplier1.setIsLiquidateBorrowPaused(vDai, true);

        evoq.setIsLiquidateBorrowPaused(vDai, true);

        vm.expectRevert(abi.encodeWithSignature("LiquidateBorrowIsPaused()"));
        supplier1.liquidate(vDai, vUsdc, address(supplier2), amount);
    }
}
