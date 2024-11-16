// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/interfaces/venus/IVenus.sol";

import "solmate/utils/SafeTransferLib.sol";

contract Attacker {
    using SafeTransferLib for ERC20;

    receive() external payable {}

    function approve(address _token, address _spender, uint256 _amount) external {
        ERC20(_token).safeApprove(_spender, _amount);
    }

    function transfer(address _token, address _recipient, uint256 _amount) external {
        ERC20(_token).safeTransfer(_recipient, _amount);
    }

    function deposit(address _asset, uint256 _amount) external {
        IVToken(_asset).mint(_amount);
    }
}
