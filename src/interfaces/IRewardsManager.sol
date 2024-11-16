// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import "./venus/IVenus.sol";

interface IRewardsManager {
    function initialize(address _evoq) external;

    function claimRewards(address[] calldata, address) external returns (uint256);

    function userUnclaimedXvsRewards(address) external view returns (uint256);

    function venusSupplierIndex(address, address) external view returns (uint256);

    function venusBorrowerIndex(address, address) external view returns (uint256);

    function getLocalXvsSupplyState(address _vTokenAddress)
        external
        view
        returns (IComptroller.VenusMarketState memory);

    function getLocalXvsBorrowState(address _vTokenAddress)
        external
        view
        returns (IComptroller.VenusMarketState memory);

    function accrueUserSupplyUnclaimedRewards(address, address, uint256) external;

    function accrueUserBorrowUnclaimedRewards(address, address, uint256) external;
}
