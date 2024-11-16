// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "./MarketsLens.sol";

/// @title RewardsLens.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice Intermediary layer serving as proxy to lighten the bytecode weight of the Lens.
abstract contract RewardsLens is MarketsLens {
    /// EXTERNAL ///

    /// @notice Returns the unclaimed XVS rewards for the given vToken addresses.
    /// @param _poolTokens The vToken addresses for which to compute the rewards.
    /// @param _user The address of the user.
    function getUserUnclaimedRewards(address[] calldata _poolTokens, address _user) external view returns (uint256) {
        return lensExtension.getUserUnclaimedRewards(_poolTokens, _user);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _supplier The address of the supplier.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function getAccruedSupplierXvs(address _supplier, address _poolToken, uint256 _balance)
        external
        view
        returns (uint256)
    {
        return lensExtension.getAccruedSupplierXvs(_supplier, _poolToken, _balance);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _supplier The address of the supplier.
    /// @param _poolToken The vToken address.
    /// @return The accrued XVS rewards.
    function getAccruedSupplierXvs(address _supplier, address _poolToken) external view returns (uint256) {
        return lensExtension.getAccruedSupplierXvs(_supplier, _poolToken);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _borrower The address of the borrower.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function getAccruedBorrowerXvs(address _borrower, address _poolToken, uint256 _balance)
        external
        view
        returns (uint256)
    {
        return lensExtension.getAccruedBorrowerXvs(_borrower, _poolToken, _balance);
    }

    /// @notice Returns the accrued XVS rewards of a user since the last update.
    /// @param _borrower The address of the borrower.
    /// @param _poolToken The vToken address.
    /// @return The accrued XVS rewards.
    function getAccruedBorrowerXvs(address _borrower, address _poolToken) external view returns (uint256) {
        return lensExtension.getAccruedBorrowerXvs(_borrower, _poolToken);
    }

    /// @notice Returns the updated XVS supply index.
    /// @param _poolToken The vToken address.
    /// @return The updated XVS supply index.
    function getCurrentXvsSupplyIndex(address _poolToken) external view returns (uint256) {
        return lensExtension.getCurrentXvsSupplyIndex(_poolToken);
    }

    /// @notice Returns the updated XVS borrow index.
    /// @param _poolToken The vToken address.
    /// @return The updated XVS borrow index.
    function getCurrentXvsBorrowIndex(address _poolToken) external view returns (uint256) {
        return lensExtension.getCurrentXvsBorrowIndex(_poolToken);
    }
}
