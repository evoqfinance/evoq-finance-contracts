// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/interfaces/venus/IVenus.sol";

/// Price Oracle for liquidation tests
contract SimplePriceOracle is IVenusOracle {
    address public constant wBnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant vBnb = 0xA07c5b74C9B40447a954e1466938b865b6BBea36;

    mapping(address => uint256) public prices;

    function getUnderlyingPrice(address _vToken) public view returns (uint256) {
        if (_vToken == vBnb) return prices[wBnb];
        return prices[IVToken(_vToken).underlying()];
    }

    function setUnderlyingPrice(address _vToken, uint256 _underlyingPriceMantissa) public {
        if (_vToken == vBnb) prices[wBnb] = _underlyingPriceMantissa;
        else prices[IVToken(_vToken).underlying()] = _underlyingPriceMantissa;
    }

    function setDirectPrice(address _asset, uint256 _price) public {
        prices[_asset] = _price;
    }
}
