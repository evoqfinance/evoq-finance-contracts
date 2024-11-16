// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestMarketMember is TestSetup {
    function testShouldNotWithdrawWhenNotMarketMember() public {
        hevm.expectRevert(abi.encodeWithSignature("UserNotMemberOfMarket()"));
        supplier1.withdraw(vDai, 1 ether);
    }

    function testShouldNotRepayWhenNotMarketMember() public {
        supplier1.approve(dai, 1 ether);
        hevm.expectRevert(abi.encodeWithSignature("UserNotMemberOfMarket()"));
        supplier1.repay(vDai, 1 ether);
    }

    function testShouldNotLiquidateUserNotOnMemberOfMarketAsCollateral() public {
        supplier1.approve(wBnb, 1 ether);
        supplier1.supply(vBnb, 1 ether);
        supplier1.borrow(vUsdc, (1 ether));

        hevm.expectRevert(abi.encodeWithSignature("UserNotMemberOfMarket()"));
        supplier2.liquidate(vUsdc, vDai, address(supplier1), 1 ether);
    }

    function testShouldNotLiquidateUserNotOnMemberOfMarketAsBorrow() public {
        supplier1.approve(wBnb, 1 ether);
        supplier1.supply(vBnb, 1 ether);
        supplier1.borrow(vUsdc, (1 ether));

        hevm.expectRevert(abi.encodeWithSignature("UserNotMemberOfMarket()"));
        supplier2.liquidate(vDai, vBnb, address(supplier1), 1 ether);
    }
}
