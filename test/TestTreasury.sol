// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestTreasury is TestSetup {
    using CompoundMath for uint256;

    function testShouldSetTreasuryVaultOnlyByOwner() public {
        Treasury treasuryVault = new Treasury();
        evoq.setTreasuryVault(address(treasuryVault));
        assertEq(address(treasuryVault), evoq.treasuryVault());

        hevm.prank(address(0));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0)));
        evoq.setTreasuryVault(address(treasuryVault));
    }

    function testShouldSetTreasuryPercentMatissa() public {
        evoq.setTreasuryPercentMantissa(0.05 ether);
        assertEq(0.05 ether, evoq.treasuryPercentMantissa());
    }

    function testShouldLiquidateAndSendToTreasury() public {
        Treasury treasuryVault = new Treasury();
        evoq.setTreasuryVault(address(treasuryVault));
        uint256 treasuryPercentMantissa = 0.05 ether;
        evoq.setTreasuryPercentMantissa(treasuryPercentMantissa);
        uint256 treasuryBalanceBefore = ERC20(usdc).balanceOf(address(treasuryVault)); // 0

        User liquidator = borrower3;
        uint256 liquidatorBalanceBefore = liquidator.balanceOf(usdc); // 1,000,000 USDC
        uint256 amountToSeize;

        {
            uint256 collateral = 100_000 ether;

            borrower1.approve(usdc, address(evoq), (collateral));
            borrower1.supply(vUsdc, (collateral));

            (, uint256 amount) = lens.getUserMaxCapacitiesForAsset(address(borrower1), vDai); // 82,511.05050711057 DAI
            borrower1.borrow(vDai, amount);

            (, uint256 collateralOnPool) = evoq.supplyBalanceInOf(vUsdc, address(borrower1)); // 415469214283361

            moveOneBlockForwardBorrowRepay();

            // Change Oracle.
            SimplePriceOracle customOracle = createAndSetCustomPriceOracle();
            customOracle.setDirectPrice(usdc, (oracle.getUnderlyingPrice(vUsdc) * 98) / 100);

            // Liquidate.
            uint256 toRepay = amount / 2; // 41,255.5252535553 DAI

            liquidator.approve(dai, address(evoq), toRepay);
            liquidator.liquidate(vDai, vUsdc, address(borrower1), toRepay);

            // Check borrower1 borrow balance.
            (uint256 inP2PBorrower, uint256 onPoolBorrower) = evoq.borrowBalanceInOf(vDai, address(borrower1));
            uint256 expectedBorrowBalanceOnPool = toRepay.div(IVToken(vDai).borrowIndex());
            testEqualityLarge(onPoolBorrower, expectedBorrowBalanceOnPool, "borrower borrow on pool");
            assertEq(inP2PBorrower, 0, "borrower borrow in peer-to-peer");

            // Check borrower1 supply balance.
            (inP2PBorrower, onPoolBorrower) = evoq.supplyBalanceInOf(vUsdc, address(borrower1));

            uint256 collateralPrice = customOracle.getUnderlyingPrice(vUsdc);
            uint256 borrowedPrice = customOracle.getUnderlyingPrice(vDai);

            amountToSeize =
                toRepay.mul(comptroller.liquidationIncentiveMantissa()).mul(borrowedPrice).div(collateralPrice);

            uint256 expectedOnPool = collateralOnPool - amountToSeize.div(IVToken(vUsdc).exchangeRateCurrent());

            testEquality(onPoolBorrower, expectedOnPool, "borrower supply on pool");
            assertEq(inP2PBorrower, 0, "borrower supply in peer-to-peer");
        }

        {
            // Check liquidator balance.
            uint256 amountForTreasury =
                amountToSeize.mul(treasuryPercentMantissa).div(comptroller.liquidationIncentiveMantissa());

            uint256 liquidatorBalanceAfter = liquidator.balanceOf(usdc); // 44,196.4285714285 USDC
            uint256 expectedAmountForLiquidator = amountToSeize - amountForTreasury;

            assertEq(
                liquidatorBalanceAfter - liquidatorBalanceBefore, expectedAmountForLiquidator, "amount for liquidator"
            );

            // Check treasury balance.
            uint256 treasuryBalanceAfter = ERC20(usdc).balanceOf(address(treasuryVault)); // 2,104.5918367347 USDC
            assertEq(treasuryBalanceAfter - treasuryBalanceBefore, amountForTreasury, "amount for treasury");

            // Withdraw from treasury to admin.
            User admin = new User(evoq, wbnbGateway);

            // Cannot withdraw if not owner
            hevm.prank(address(supplier1));
            hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));
            treasuryVault.withdrawTreasuryBEP20(usdc, type(uint256).max, address(admin));

            // Only owner can withdraw
            treasuryVault.withdrawTreasuryBEP20(usdc, type(uint256).max, address(admin));
            uint256 adminBalance = admin.balanceOf(usdc);
            assertEq(amountForTreasury, adminBalance, "withdraw from treasury");
        }
    }

    function testShouldWithdrawBNBFromTreasury() public {
        Treasury treasuryVault = new Treasury();
        evoq.setTreasuryVault(address(treasuryVault));
        uint256 amountInTreasury = 100 ether;
        hevm.deal(address(treasuryVault), amountInTreasury);

        User admin = new User(evoq, wbnbGateway);

        // revert if not owner
        hevm.prank(address(admin));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(admin)));
        treasuryVault.withdrawTreasuryBNB(type(uint256).max, payable(admin));

        // only owner can withdraw
        treasuryVault.withdrawTreasuryBNB(type(uint256).max, payable(admin));
        assertEq(address(admin).balance, amountInTreasury, "withdraw bnb from treasury");
    }
}
