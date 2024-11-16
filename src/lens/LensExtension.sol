// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "../interfaces/IRewardsManager.sol";
import "../interfaces/IEvoq.sol";
import "./interfaces/ILensExtension.sol";

import "morpho-utils/math/CompoundMath.sol";

/// @title LensExtension.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice This contract is an extension of the Lens. It should be deployed before the Lens, as the Lens depends on its address to extends its functionalities.
contract LensExtension is ILensExtension {
    using CompoundMath for uint256;

    /// STORAGE ///

    IEvoq public immutable evoq;
    IComptroller internal immutable comptroller;
    IRewardsManager internal immutable rewardsManager;

    /// ERRORS ///

    /// @notice Thrown when an invalid vToken address is passed to claim rewards.
    error InvalidCToken();

    /// CONSTRUCTOR ///

    /// @notice Constructs the contract.
    /// @param _evoq The address of the main Evoq contract.
    constructor(address _evoq) {
        evoq = IEvoq(_evoq);
        comptroller = IComptroller(evoq.comptroller());
        rewardsManager = IRewardsManager(evoq.rewardsManager());
    }

    /// EXTERNAL ///

    /// @notice Returns the unclaimed XVS rewards for the given vToken addresses.
    /// @param _poolTokens The vToken addresses for which to compute the rewards.
    /// @param _user The address of the user.
    function getUserUnclaimedRewards(address[] calldata _poolTokens, address _user)
        external
        view
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards = rewardsManager.userUnclaimedXvsRewards(_user);

        for (uint256 i; i < _poolTokens.length;) {
            address poolToken = _poolTokens[i];

            (bool isListed,,) = comptroller.markets(poolToken);
            if (!isListed) revert InvalidCToken();

            unclaimedRewards += getAccruedSupplierXvs(_user, poolToken) + getAccruedBorrowerXvs(_user, poolToken);

            unchecked {
                ++i;
            }
        }
    }

    /// PUBLIC ///

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _supplier The address of the supplier.
    /// @param _poolToken The vToken address.
    /// @return The accrued XVS rewards.
    function getAccruedSupplierXvs(address _supplier, address _poolToken) public view returns (uint256) {
        return getAccruedSupplierXvs(_supplier, _poolToken, evoq.supplyBalanceInOf(_poolToken, _supplier).onPool);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _borrower The address of the borrower.
    /// @param _poolToken The vToken address.
    /// @return The accrued XVS rewards.
    function getAccruedBorrowerXvs(address _borrower, address _poolToken) public view returns (uint256) {
        return getAccruedBorrowerXvs(_borrower, _poolToken, evoq.borrowBalanceInOf(_poolToken, _borrower).onPool);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _supplier The address of the supplier.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function getAccruedSupplierXvs(address _supplier, address _poolToken, uint256 _balance)
        public
        view
        returns (uint256)
    {
        uint256 supplierIndex = rewardsManager.venusSupplierIndex(_poolToken, _supplier);

        if (supplierIndex == 0) return 0;
        return (_balance * (getCurrentXvsSupplyIndex(_poolToken) - supplierIndex)) / 1e36;
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _borrower The address of the borrower.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function getAccruedBorrowerXvs(address _borrower, address _poolToken, uint256 _balance)
        public
        view
        returns (uint256)
    {
        uint256 borrowerIndex = rewardsManager.venusBorrowerIndex(_poolToken, _borrower);

        if (borrowerIndex == 0) return 0;
        return (_balance * (getCurrentXvsBorrowIndex(_poolToken) - borrowerIndex)) / 1e36;
    }

    /// @notice Returns the updated XVS supply index.
    /// @param _poolToken The vToken address.
    /// @return The updated XVS supply index.
    function getCurrentXvsSupplyIndex(address _poolToken) public view returns (uint256) {
        IComptroller.VenusMarketState memory localSupplyState = rewardsManager.getLocalXvsSupplyState(_poolToken);

        if (localSupplyState.block == block.number) {
            return localSupplyState.index;
        } else {
            IComptroller.VenusMarketState memory supplyState = comptroller.venusSupplyState(_poolToken);

            uint256 deltaBlocks = block.number - supplyState.block;
            uint256 supplySpeed = comptroller.venusSupplySpeeds(_poolToken);

            if (deltaBlocks > 0 && supplySpeed > 0) {
                uint256 supplyTokens = IVToken(_poolToken).totalSupply();
                uint256 ratio = supplyTokens > 0 ? (deltaBlocks * supplySpeed * 1e36) / supplyTokens : 0;

                return supplyState.index + ratio;
            }

            return supplyState.index;
        }
    }

    /// @notice Returns the updated XVS borrow index.
    /// @param _poolToken The vToken address.
    /// @return The updated XVS borrow index.
    function getCurrentXvsBorrowIndex(address _poolToken) public view returns (uint256) {
        IComptroller.VenusMarketState memory localBorrowState = rewardsManager.getLocalXvsBorrowState(_poolToken);

        if (localBorrowState.block == block.number) {
            return localBorrowState.index;
        } else {
            IComptroller.VenusMarketState memory borrowState = comptroller.venusBorrowState(_poolToken);
            uint256 deltaBlocks = block.number - borrowState.block;
            uint256 borrowSpeed = comptroller.venusBorrowSpeeds(_poolToken);

            if (deltaBlocks > 0 && borrowSpeed > 0) {
                uint256 borrowAmount = IVToken(_poolToken).totalBorrows().div(IVToken(_poolToken).borrowIndex());
                uint256 ratio = borrowAmount > 0 ? (deltaBlocks * borrowSpeed * 1e36) / borrowAmount : 0;

                return borrowState.index + ratio;
            }

            return borrowState.index;
        }
    }
}
