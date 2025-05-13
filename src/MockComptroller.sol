// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVToken {
    function underlying() external view returns (address);
}

interface IAggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256 answer,
            uint256,
            uint256,
            uint80
        );
}

contract MockComptroller {
    mapping(address => address) public assetToOracle;
    mapping(address => bool) public isSupported;
    address public defaultOracle; 

    function setOracle(address asset, address oracle) external {
        assetToOracle[asset] = oracle;
        defaultOracle = oracle; // 가장 최근 등록한 oracle을 기본으로 사용
    }

    function getUnderlyingPrice(address vToken) external view returns (uint256) {
        address underlying = IVToken(vToken).underlying();
        address oracle = assetToOracle[underlying];
        require(oracle != address(0), "No oracle set");

        (, int256 price,,,) = IAggregator(oracle).latestRoundData();
        return uint256(price);
    }

    function oracle() external view returns (address) {
        return defaultOracle;
    }
    function markets(address) external pure returns (bool, uint, bool) {
        return (true, 0.5e18, false); // isListed, collateralFactorMantissa, isVenus
    }

    function getAccountLiquidity(address account) external pure returns (uint, uint, uint) {
        return (0, 1e18, 0); // error, liquidity, shortfall
    }

    function isComptroller() external pure returns (bool) {
        return true;
    }

    function supportMarket(address vToken) external returns (bool) {
        isSupported[vToken] = true;
        return true;
    }

    function liquidationIncentiveMantissa() external pure returns (uint256) {
        return 1.1e18; 
    }

    function enterMarkets(address[] calldata markets) external returns (uint[] memory) {
        uint[] memory results = new uint[](markets.length);
        for (uint i = 0; i < markets.length; i++) {
            results[i] = 0;  
        }
        return results;
    }
}
