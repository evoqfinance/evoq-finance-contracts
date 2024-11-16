// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import "./interfaces/IDataLens.sol";

import "morpho-utils/math/CompoundMath.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title DataLens.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice This contract exposes an API to query on-chain data related to the Evoq Protocol.
contract DataLens is IDataLens {
    using CompoundMath for uint256;

    IEvoq public immutable evoq;
    IComptroller public immutable comptroller;
    IRewardsManager public immutable rewardsManager;
    ILens public immutable lens;

    constructor(address _lens) {
        lens = ILens(_lens);
        evoq = lens.evoq();
        comptroller = IComptroller(evoq.comptroller());
        rewardsManager = IRewardsManager(evoq.rewardsManager());
    }

    // USERS

    function getUserSummary(address _user) external view returns (UserSummary memory) {
        UserSummary memory data;

        (data.collateralUsd, data.debtUsd, data.maxDebtUsd) = lens.getUserBalanceStates(_user, new address[](0));

        address[] memory markets = evoq.getAllMarkets();
        uint256 nbMarkets = markets.length;

        for (uint256 i; i < nbMarkets;) {
            address _poolToken = markets[i];
            uint256 underlyingPrice = IVenusOracle(comptroller.oracle()).getUnderlyingPrice(_poolToken);

            (,, uint256 supplyTotal) = lens.getCurrentSupplyBalanceInOf(_poolToken, _user);
            (,, uint256 borrowTotal) = lens.getCurrentBorrowBalanceInOf(_poolToken, _user);

            (uint256 supplyRate, uint256 borrowRate) = _getCurrentUserRatePerBlock(_poolToken, _user);
            data.totalSupplyRate += supplyRate.mul(supplyTotal).mul(underlyingPrice);
            data.totalBorrowRate += borrowRate.mul(borrowTotal).mul(underlyingPrice);

            unchecked {
                ++i;
            }
        }

        return data;
    }

    function getUserMarketsData(address _user) external view returns (UserMarketData[] memory) {
        address[] memory markets = evoq.getAllMarkets();
        UserMarketData[] memory userMarketsData = new UserMarketData[](_user != address(0) ? markets.length : 0);

        for (uint256 i; i < markets.length;) {
            address poolToken = markets[i];

            userMarketsData[i] = _getUserMarketDetail(poolToken, _user);

            unchecked {
                ++i;
            }
        }

        return userMarketsData;
    }

    function getUserMarketDetail(address _poolToken, address _user) external view returns (UserMarketData memory) {
        return _getUserMarketDetail(_poolToken, _user);
    }

    function _getUserMarketDetail(address _poolToken, address _user) internal view returns (UserMarketData memory) {
        UserMarketData memory data;

        data.poolToken = _poolToken;
        data.underlying = _poolToken == evoq.vBnb() ? evoq.wBnb() : IVToken(_poolToken).underlying();

        if (_user != address(0)) {
            (data.supplyOnPool, data.supplyInP2P, data.supplyTotal) =
                lens.getCurrentSupplyBalanceInOf(_poolToken, _user);
            (data.borrowOnPool, data.borrowInP2P, data.borrowTotal) =
                lens.getCurrentBorrowBalanceInOf(_poolToken, _user);

            data.underlyingPrice = IVenusOracle(comptroller.oracle()).getUnderlyingPrice(_poolToken);

            (data.supplyRate, data.borrowRate) = _getCurrentUserRatePerBlock(_poolToken, _user);
            (data.p2pSupplyRate, data.p2pBorrowRate, data.poolSupplyRate, data.poolBorrowRate) =
                lens.getRatesPerBlock(_poolToken);
        }

        return data;
    }

    function _getCurrentUserRatePerBlock(address _poolToken, address _user)
        internal
        view
        returns (uint256 supplyRatePerBlock, uint256 borrowRatePerBlock)
    {
        supplyRatePerBlock = lens.getCurrentUserSupplyRatePerBlock(_poolToken, _user);
        borrowRatePerBlock = lens.getCurrentUserBorrowRatePerBlock(_poolToken, _user);
    }

    // MARKETS

    function getMarketSummary() external view returns (MarketSummary memory) {
        MarketSummary memory data;

        (data.p2pSupply, data.poolSupply, data.totalSupply) = lens.getTotalSupply();
        (data.p2pBorrow, data.poolBorrow, data.totalBorrow) = lens.getTotalBorrow();

        data.matchingEfficiency = _calculateMatchingEfficiency();

        return data;
    }

    function _calculateMatchingEfficiency() internal view returns (uint256) {
        address[] memory markets = evoq.getAllMarkets();
        uint256 nbMarkets = markets.length;

        uint256 p2pMatched;
        uint256 p2pAvailableMatch;

        for (uint256 i = 0; i < nbMarkets;) {
            address _poolToken = markets[i];
            uint256 underlyingPrice = IVenusOracle(comptroller.oracle()).getUnderlyingPrice(_poolToken);

            (,, uint256 p2pSupplyAmount, uint256 p2pBorrowAmount, uint256 poolSupplyAmount, uint256 poolBorrowAmount) =
                lens.getMainMarketData(_poolToken);

            uint256 totalSupplyAmount = p2pSupplyAmount + poolSupplyAmount;
            uint256 totalBorrowAmount = p2pBorrowAmount + poolBorrowAmount;

            if (totalSupplyAmount > totalBorrowAmount) {
                p2pAvailableMatch += totalBorrowAmount.mul(underlyingPrice);
                p2pMatched += p2pBorrowAmount.mul(underlyingPrice);
            } else {
                p2pAvailableMatch += totalSupplyAmount.mul(underlyingPrice);
                p2pMatched += p2pSupplyAmount.mul(underlyingPrice);
            }

            unchecked {
                ++i;
            }
        }
        uint256 efficiency;

        if (p2pAvailableMatch == 0 || p2pMatched == 0) {
            efficiency = 0;
        } else {
            efficiency = p2pMatched.div(p2pAvailableMatch);
        }

        return efficiency;
    }

    function getMarketsData() external view returns (MarketsData[] memory) {
        address[] memory markets = evoq.getAllMarkets();
        MarketsData[] memory marketsData = new MarketsData[](markets.length);

        for (uint256 i; i < markets.length;) {
            address poolToken = markets[i];
            MarketsData memory data;

            data.poolToken = poolToken;
            data.underlying = poolToken == evoq.vBnb() ? evoq.wBnb() : IVToken(poolToken).underlying();

            (data.supplyRate, data.borrowRate, data.supplyInP2P, data.borrowInP2P, data.supplyOnPool, data.borrowOnPool)
            = lens.getMainMarketData(poolToken);
            data.supplyTotal = data.supplyInP2P + data.supplyOnPool;
            data.borrowTotal = data.borrowInP2P + data.borrowOnPool;

            data.underlyingPrice = IVenusOracle(comptroller.oracle()).getUnderlyingPrice(poolToken);

            uint256 totalSupplies = IVToken(poolToken).totalSupply().mul(IVToken(poolToken).exchangeRateStored());
            if (totalSupplies < IVToken(poolToken).totalBorrows()) {
                data.availableLiquidity = 0;
            } else {
                data.availableLiquidity = totalSupplies - IVToken(poolToken).totalBorrows();
            }

            (data.p2pSupplyRate, data.p2pBorrowRate, data.poolSupplyRate, data.poolBorrowRate) =
                lens.getRatesPerBlock(poolToken);

            marketsData[i] = data;

            unchecked {
                ++i;
            }
        }

        return marketsData;
    }

    function getMarketDetail(address _poolToken) external view returns (MarketDetailData memory) {
        MarketDetailData memory data;

        data.poolToken = _poolToken;
        data.underlying = _poolToken == evoq.vBnb() ? evoq.wBnb() : IVToken(_poolToken).underlying();

        (data.supplyRate, data.borrowRate, data.supplyInP2P, data.borrowInP2P, data.supplyOnPool, data.borrowOnPool) =
            lens.getMainMarketData(_poolToken);
        data.supplyTotal = data.supplyInP2P + data.supplyOnPool;
        data.borrowTotal = data.borrowInP2P + data.borrowOnPool;

        data.underlyingPrice = IVenusOracle(comptroller.oracle()).getUnderlyingPrice(_poolToken);

        uint256 totalSupplies = IVToken(_poolToken).totalSupply().mul(IVToken(_poolToken).exchangeRateStored());
        if (totalSupplies < IVToken(_poolToken).totalBorrows()) {
            data.availableLiquidity = 0;
        } else {
            data.availableLiquidity = totalSupplies - IVToken(_poolToken).totalBorrows();
        }

        (data.p2pSupplyRate, data.p2pBorrowRate, data.poolSupplyRate, data.poolBorrowRate) =
            lens.getRatesPerBlock(_poolToken);

        return data;
    }
}
