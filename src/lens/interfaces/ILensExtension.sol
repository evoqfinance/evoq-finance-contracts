// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import "../../interfaces/venus/IVenus.sol";
import "../../interfaces/IRewardsManager.sol";
import "../../interfaces/IEvoq.sol";

interface ILensExtension {
    function evoq() external view returns (IEvoq);

    function getUserUnclaimedRewards(address[] calldata _poolTokens, address _user)
        external
        view
        returns (uint256 unclaimedRewards);

    function getAccruedSupplierXvs(address _supplier, address _poolToken, uint256 _balance)
        external
        view
        returns (uint256);

    function getAccruedBorrowerXvs(address _borrower, address _poolToken, uint256 _balance)
        external
        view
        returns (uint256);

    function getAccruedSupplierXvs(address _supplier, address _poolToken) external view returns (uint256);

    function getAccruedBorrowerXvs(address _borrower, address _poolToken) external view returns (uint256);

    function getCurrentXvsSupplyIndex(address _poolToken) external view returns (uint256);

    function getCurrentXvsBorrowIndex(address _poolToken) external view returns (uint256);
}
