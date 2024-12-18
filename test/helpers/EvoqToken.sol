// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EvoqToken is ERC20, Ownable {
    constructor(
        address _receiver
    ) ERC20("EvoqToken", "MORPHO", 18) Ownable(msg.sender) {
        _mint(_receiver, 1_000_000_000 ether);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
