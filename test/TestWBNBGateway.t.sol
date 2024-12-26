// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestWBNBGateway is TestSetup {
    using CompoundMath for uint256;

    function testSupplyBNB() public {
        uint256 supplyAmount = 1 ether;
        supplier1.supplyBNB{value: supplyAmount}(address(supplier1));
    }
}
