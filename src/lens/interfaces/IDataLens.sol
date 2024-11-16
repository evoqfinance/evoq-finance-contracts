// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import "./ILens.sol";
import "../../interfaces/venus/IVenus.sol";
import "../../interfaces/IRewardsManager.sol";
import "../../interfaces/IEvoq.sol";

interface IDataLens {
    function lens() external view returns (ILens);

    function evoq() external view returns (IEvoq);

    function comptroller() external view returns (IComptroller);

    function rewardsManager() external view returns (IRewardsManager);

    struct UserSummary {
        uint256 collateralUsd;
        uint256 debtUsd;
        uint256 maxDebtUsd;
        uint256 totalSupplyRate;
        uint256 totalBorrowRate;
    }

    struct UserMarketData {
        address poolToken;
        address underlying;
        uint256 underlyingPrice;
        uint256 supplyOnPool;
        uint256 supplyInP2P;
        uint256 supplyTotal;
        uint256 borrowOnPool;
        uint256 borrowInP2P;
        uint256 borrowTotal;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 p2pSupplyRate;
        uint256 p2pBorrowRate;
        uint256 poolSupplyRate;
        uint256 poolBorrowRate;
    }

    struct MarketSummary {
        uint256 totalSupply;
        uint256 p2pSupply;
        uint256 poolSupply;
        uint256 totalBorrow;
        uint256 p2pBorrow;
        uint256 poolBorrow;
        uint256 matchingEfficiency;
    }

    struct MarketsData {
        address poolToken;
        address underlying;
        uint256 underlyingPrice;
        uint256 supplyOnPool;
        uint256 supplyInP2P;
        uint256 supplyTotal;
        uint256 borrowOnPool;
        uint256 borrowInP2P;
        uint256 borrowTotal;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 p2pSupplyRate;
        uint256 p2pBorrowRate;
        uint256 poolSupplyRate;
        uint256 poolBorrowRate;
        uint256 availableLiquidity;
    }

    struct MarketDetailData {
        address poolToken;
        address underlying;
        uint256 underlyingPrice;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 p2pSupplyRate;
        uint256 p2pBorrowRate;
        uint256 poolSupplyRate;
        uint256 poolBorrowRate;
        uint256 supplyInP2P;
        uint256 borrowInP2P;
        uint256 supplyOnPool;
        uint256 borrowOnPool;
        uint256 supplyTotal;
        uint256 borrowTotal;
        uint256 availableLiquidity;
    }

    function getUserSummary(address _user) external view returns (UserSummary memory);

    function getUserMarketsData(address _user) external view returns (UserMarketData[] memory);

    function getUserMarketDetail(address poolToken, address _user) external view returns (UserMarketData memory);

    function getMarketsData() external view returns (MarketsData[] memory);

    function getMarketDetail(address _poolToken) external view returns (MarketDetailData memory);
}
