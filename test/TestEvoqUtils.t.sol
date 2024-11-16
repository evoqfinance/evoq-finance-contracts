// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestEvoqUtils is TestSetup {
    function testUserShouldNotUpdateP2PIndexesOfMarketNotCreated() public {
        hevm.prank(address(2));
        hevm.expectRevert(abi.encodeWithSignature("MarketNotCreated()"));
        evoq.updateP2PIndexes(vCake);
    }
}
