// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "solmate/utils/SafeTransferLib.sol";
import "morpho-utils/math/Math.sol";
import "morpho-utils/math/CompoundMath.sol";
import "morpho-utils/DelegateCall.sol";

import "./EvoqStorage.sol";

/// @title EvoqUtils.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice Modifiers, getters and other util functions for Evoq.
abstract contract EvoqUtils is EvoqStorage {
    using DoubleLinkedList for DoubleLinkedList.List;
    using CompoundMath for uint256;
    using DelegateCall for address;
    using Math for uint256;

    /// ERRORS ///

    /// @notice Thrown when the Venus's oracle failed.
    error VenusOracleFailed();

    /// @notice Thrown when the market is not created yet.
    error MarketNotCreated();

    /// MODIFIERS ///

    /// @notice Prevents to update a market not created yet.
    /// @param _poolToken The address of the market to check.
    modifier isMarketCreated(address _poolToken) {
        if (!marketStatus[_poolToken].isCreated) revert MarketNotCreated();
        _;
    }

    /// EXTERNAL ///

    /// @notice Returns all markets entered by a given user.
    /// @param _user The address of the user.
    /// @return The list of markets entered by this user.
    function getEnteredMarkets(address _user) external view returns (address[] memory) {
        return enteredMarkets[_user];
    }

    /// @notice Returns all created markets.
    /// @return The list of market addresses.
    function getAllMarkets() external view returns (address[] memory) {
        return marketsCreated;
    }

    /// @notice Gets the head of the data structure on a specific market (for UI).
    /// @param _poolToken The address of the market from which to get the head.
    /// @param _positionType The type of user from which to get the head.
    /// @return head The head in the data structure.
    function getHead(address _poolToken, Types.PositionType _positionType) external view returns (address head) {
        if (_positionType == Types.PositionType.SUPPLIERS_IN_P2P) {
            head = suppliersInP2P[_poolToken].getHead();
        } else if (_positionType == Types.PositionType.SUPPLIERS_ON_POOL) {
            head = suppliersOnPool[_poolToken].getHead();
        } else if (_positionType == Types.PositionType.BORROWERS_IN_P2P) {
            head = borrowersInP2P[_poolToken].getHead();
        } else if (_positionType == Types.PositionType.BORROWERS_ON_POOL) {
            head = borrowersOnPool[_poolToken].getHead();
        }
    }

    /// @notice Gets the next user after `_user` in the data structure on a specific market (for UI).
    /// @dev Beware that this function does not give the account with the highest liquidity.
    /// @param _poolToken The address of the market from which to get the user.
    /// @param _positionType The type of user from which to get the next user.
    /// @param _user The address of the user from which to get the next user.
    /// @return next The next user in the data structure.
    function getNext(address _poolToken, Types.PositionType _positionType, address _user)
        external
        view
        returns (address next)
    {
        if (_positionType == Types.PositionType.SUPPLIERS_IN_P2P) {
            next = suppliersInP2P[_poolToken].getNext(_user);
        } else if (_positionType == Types.PositionType.SUPPLIERS_ON_POOL) {
            next = suppliersOnPool[_poolToken].getNext(_user);
        } else if (_positionType == Types.PositionType.BORROWERS_IN_P2P) {
            next = borrowersInP2P[_poolToken].getNext(_user);
        } else if (_positionType == Types.PositionType.BORROWERS_ON_POOL) {
            next = borrowersOnPool[_poolToken].getNext(_user);
        }
    }

    /// @notice Updates the peer-to-peer indexes.
    /// @dev Note: This function updates the exchange rate on Venus. As a consequence only a call to exchangeRateStored() is necessary to get the most up to date exchange rate.
    /// @param _poolToken The address of the market to update.
    function updateP2PIndexes(address _poolToken) external isMarketCreated(_poolToken) {
        _updateP2PIndexes(_poolToken);
    }

    /// INTERNAL ///

    /// @dev Updates the peer-to-peer indexes.
    /// @dev Note: This function updates the exchange rate on Venus. As a consequence only a call to exchangeRateStored() is necessary to get the most up to date exchange rate.
    /// @param _poolToken The address of the market to update.
    function _updateP2PIndexes(address _poolToken) internal {
        address(interestRatesManager).functionDelegateCall(
            abi.encodeWithSelector(interestRatesManager.updateP2PIndexes.selector, _poolToken)
        );
    }

    /// @dev Checks whether the user has enough collateral to maintain such a borrow position.
    /// @dev Expects the given user's entered markets to include the given market.
    /// @dev Expects the given market's pool & peer-to-peer indexes to have been updated.
    /// @dev Expects `_withdrawnAmount` to be less than or equal to the given user's supply on the given market.
    /// @param _user The user to check.
    /// @param _poolToken The market to hypothetically withdraw/borrow in.
    /// @param _withdrawnAmount The amount of tokens to hypothetically withdraw (in underlying).
    /// @param _borrowedAmount The amount of tokens to hypothetically borrow (in underlying).
    function _isLiquidatable(address _user, address _poolToken, uint256 _withdrawnAmount, uint256 _borrowedAmount)
        internal
        view
        returns (bool)
    {
        IVenusOracle oracle = IVenusOracle(comptroller.oracle());
        uint256 numberOfEnteredMarkets = enteredMarkets[_user].length;

        Types.AssetLiquidityData memory assetData;
        uint256 maxDebtUsd;
        uint256 debtUsd;
        uint256 i;

        while (i < numberOfEnteredMarkets) {
            address poolTokenEntered = enteredMarkets[_user][i];

            assetData = _getUserLiquidityDataForAsset(_user, poolTokenEntered, oracle);
            maxDebtUsd += assetData.maxDebtUsd;
            debtUsd += assetData.debtUsd;

            if (_poolToken == poolTokenEntered) {
                if (_borrowedAmount > 0) {
                    debtUsd += _borrowedAmount.mul(assetData.underlyingPrice);
                }

                if (_withdrawnAmount > 0) {
                    maxDebtUsd -= _withdrawnAmount.mul(assetData.underlyingPrice).mul(assetData.collateralFactor);
                }
            }

            unchecked {
                ++i;
            }
        }

        return debtUsd > maxDebtUsd;
    }

    /// @notice Returns the data related to `_poolToken` for the `_user`.
    /// @dev Note: Must be called after calling `_updateP2PIndexes()` to have the most up-to-date indexes.
    /// @param _user The user to determine data for.
    /// @param _poolToken The address of the market.
    /// @param _oracle The oracle used.
    /// @return assetData The data related to this asset.
    function _getUserLiquidityDataForAsset(address _user, address _poolToken, IVenusOracle _oracle)
        internal
        view
        returns (Types.AssetLiquidityData memory assetData)
    {
        assetData.underlyingPrice = _oracle.getUnderlyingPrice(_poolToken);
        if (assetData.underlyingPrice == 0) revert VenusOracleFailed();
        (, assetData.collateralFactor,) = comptroller.markets(_poolToken);

        assetData.collateralUsd = _getUserSupplyBalanceInOf(_poolToken, _user).mul(assetData.underlyingPrice);
        assetData.debtUsd = _getUserBorrowBalanceInOf(_poolToken, _user).mul(assetData.underlyingPrice);
        assetData.maxDebtUsd = assetData.collateralUsd.mul(assetData.collateralFactor);
    }

    /// @dev Returns the supply balance of `_user` in the `_poolToken` market.
    /// @dev Note: Computes the result with the stored indexes, which are not always the most up to date ones.
    /// @param _user The address of the user.
    /// @param _poolToken The market where to get the supply amount.
    /// @return The supply balance of the user (in underlying).
    function _getUserSupplyBalanceInOf(address _poolToken, address _user) internal view returns (uint256) {
        Types.SupplyBalance memory userSupplyBalance = supplyBalanceInOf[_poolToken][_user];
        return userSupplyBalance.inP2P.mul(p2pSupplyIndex[_poolToken])
            + userSupplyBalance.onPool.mul(IVToken(_poolToken).exchangeRateStored());
    }

    /// @dev Returns the borrow balance of `_user` in the `_poolToken` market.
    /// @dev Note: Computes the result with the stored indexes, which are not always the most up to date ones.
    /// @param _user The address of the user.
    /// @param _poolToken The market where to get the borrow amount.
    /// @return The borrow balance of the user (in underlying).
    function _getUserBorrowBalanceInOf(address _poolToken, address _user) internal view returns (uint256) {
        Types.BorrowBalance memory userBorrowBalance = borrowBalanceInOf[_poolToken][_user];
        return userBorrowBalance.inP2P.mul(p2pBorrowIndex[_poolToken])
            + userBorrowBalance.onPool.mul(IVToken(_poolToken).borrowIndex());
    }

    /// @dev Returns the underlying ERC20 token related to the pool token.
    /// @param _poolToken The address of the pool token.
    /// @return The underlying ERC20 token.
    function _getUnderlying(address _poolToken) internal view returns (ERC20) {
        if (_poolToken == vBnb) {
            // vBNB has no underlying() function.
            return ERC20(wBnb);
        } else {
            return ERC20(IVToken(_poolToken).underlying());
        }
    }

    /// @dev Checks if the user can supply without exceeding the supply cap.
    function _supplyAllowed(address _poolToken, uint256 _amount) internal view returns (bool) {
        uint256 supplyCap;
        if (capModes[_poolToken] == 1) {
            supplyCap = comptroller.supplyCaps(_poolToken);
        } else {
            supplyCap = supplyCaps[_poolToken];
        }
        require(supplyCap != 0, "market supply cap is 0");

        Types.Delta storage delta = deltas[_poolToken];
        uint256 _p2pSupplyIndex = p2pSupplyIndex[_poolToken];
        uint256 _poolSupplyIndex = IVToken(_poolToken).exchangeRateStored();
        uint256 p2pSupplyAmount =
            delta.p2pSupplyAmount.mul(_p2pSupplyIndex).zeroFloorSub(delta.p2pSupplyDelta.mul(_poolSupplyIndex));
        uint256 poolSupplyAmount = IVToken(_poolToken).balanceOf(address(this)).mul(_poolSupplyIndex);

        uint256 totalSupply = p2pSupplyAmount + poolSupplyAmount;
        uint256 nextTotalSupply = totalSupply + _amount;

        if (nextTotalSupply > supplyCap) {
            return false;
        }

        return true;
    }

    /// @dev Checks if the user can borrow without exceeding the borrow cap.
    function _borrowAllowed(address _poolToken, uint256 _amount) internal view returns (bool) {
        IVenusOracle oracle = IVenusOracle(comptroller.oracle());
        require(oracle.getUnderlyingPrice(_poolToken) != 0, "oracle failed");

        uint256 borrowCap;
        if (capModes[_poolToken] == 1) {
            borrowCap = comptroller.borrowCaps(_poolToken);
        } else {
            borrowCap = borrowCaps[_poolToken];
        }

        require(borrowCap != 0, "borrowCap is 0");

        Types.Delta storage delta = deltas[_poolToken];
        uint256 _p2pBorrowIndex = p2pBorrowIndex[_poolToken];
        uint256 _poolBorrowIndex = IVToken(_poolToken).borrowIndex();
        uint256 p2pBorrowAmount =
            delta.p2pBorrowAmount.mul(_p2pBorrowIndex).zeroFloorSub(delta.p2pBorrowDelta.mul(_poolBorrowIndex));
        uint256 poolBorrowAmount = IVToken(_poolToken).borrowBalanceStored(address(this));

        uint256 totalBorrow = p2pBorrowAmount + poolBorrowAmount;
        uint256 nextTotalBorrow = totalBorrow + _amount;

        if (nextTotalBorrow > borrowCap) {
            return false;
        }

        return true;
    }
}
