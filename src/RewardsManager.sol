// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import "./interfaces/IRewardsManager.sol";
import "./interfaces/IEvoq.sol";

import "morpho-utils/math/CompoundMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title RewardsManager.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice This contract is used to manage the XVS rewards from the Venus protocol.
contract RewardsManager is IRewardsManager, Initializable {
    using CompoundMath for uint256;
    using SafeCast for uint256;

    /// STORAGE ///

    mapping(address => uint256) public userUnclaimedXvsRewards; // The unclaimed rewards of the user.
    mapping(address => mapping(address => uint256)) public venusSupplierIndex; // The supply index of the user for a specific vToken. vToken -> user -> index.
    mapping(address => mapping(address => uint256)) public venusBorrowerIndex; // The borrow index of the user for a specific vToken. vToken -> user -> index.
    mapping(address => IComptroller.VenusMarketState) public localXvsSupplyState; // The local supply state for a specific vToken.
    mapping(address => IComptroller.VenusMarketState) public localXvsBorrowState; // The local borrow state for a specific vToken.

    IEvoq public evoq;
    IComptroller public comptroller;

    /// ERRORS ///

    /// @notice Thrown when only Evoq can call the function.
    error OnlyEvoq();

    /// @notice Thrown when an invalid vToken address is passed to claim rewards.
    error InvalidCToken();

    /// MODIFIERS ///

    /// @notice Thrown when an other address than Evoq triggers the function.
    modifier onlyEvoq() {
        if (msg.sender != address(evoq)) revert OnlyEvoq();
        _;
    }

    /// CONSTRUCTOR ///

    /// @notice Constructs the contract.
    /// @dev The contract is automatically marked as initialized when deployed so that nobody can highjack the implementation contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// UPGRADE ///

    /// @notice Initializes the RewardsManager contract.
    /// @param _evoq The address of Evoq's main contract's proxy.
    function initialize(address _evoq) external initializer {
        evoq = IEvoq(_evoq);
        comptroller = IComptroller(evoq.comptroller());
    }

    /// EXTERNAL ///

    /// @notice Returns the local XVS supply state.
    /// @param _poolToken The vToken address.
    /// @return The local XVS supply state.
    function getLocalXvsSupplyState(address _poolToken) external view returns (IComptroller.VenusMarketState memory) {
        return localXvsSupplyState[_poolToken];
    }

    /// @notice Returns the local XVS borrow state.
    /// @param _poolToken The vToken address.
    /// @return The local XVS borrow state.
    function getLocalXvsBorrowState(address _poolToken) external view returns (IComptroller.VenusMarketState memory) {
        return localXvsBorrowState[_poolToken];
    }

    /// @notice Accrues unclaimed XVS rewards for the given vToken addresses and returns the total XVS unclaimed rewards.
    /// @dev This function is called by the `evoq` to accrue XVS rewards and reset them to 0.
    /// @dev The transfer of tokens is done in the `evoq`.
    /// @param _poolTokens The vToken addresses for which to claim rewards.
    /// @param _user The address of the user.
    function claimRewards(address[] calldata _poolTokens, address _user)
        external
        onlyEvoq
        returns (uint256 totalUnclaimedRewards)
    {
        totalUnclaimedRewards = _accrueUserUnclaimedRewards(_poolTokens, _user);
        if (totalUnclaimedRewards > 0) userUnclaimedXvsRewards[_user] = 0;
    }

    /// @notice Updates the unclaimed XVS rewards of the user.
    /// @param _user The address of the user.
    /// @param _poolToken The vToken address.
    /// @param _userBalance The user balance of tokens in the distribution.
    function accrueUserSupplyUnclaimedRewards(address _user, address _poolToken, uint256 _userBalance)
        external
        onlyEvoq
    {
        _updateSupplyIndex(_poolToken);
        userUnclaimedXvsRewards[_user] += _accrueSupplierXvs(_user, _poolToken, _userBalance);
    }

    /// @notice Updates the unclaimed XVS rewards of the user.
    /// @param _user The address of the user.
    /// @param _poolToken The vToken address.
    /// @param _userBalance The user balance of tokens in the distribution.
    function accrueUserBorrowUnclaimedRewards(address _user, address _poolToken, uint256 _userBalance)
        external
        onlyEvoq
    {
        _updateBorrowIndex(_poolToken);
        userUnclaimedXvsRewards[_user] += _accrueBorrowerXvs(_user, _poolToken, _userBalance);
    }

    /// INTERNAL ///

    /// @notice Accrues unclaimed XVS rewards for the vToken addresses and returns the total unclaimed XVS rewards.
    /// @param _poolTokens The vToken addresses for which to accrue rewards.
    /// @param _user The address of the user.
    /// @return unclaimedRewards The user unclaimed rewards.
    function _accrueUserUnclaimedRewards(address[] calldata _poolTokens, address _user)
        internal
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards = userUnclaimedXvsRewards[_user];

        for (uint256 i; i < _poolTokens.length;) {
            address poolToken = _poolTokens[i];

            (bool isListed,,) = comptroller.markets(poolToken);
            if (!isListed) revert InvalidCToken();

            _updateSupplyIndex(poolToken);
            unclaimedRewards += _accrueSupplierXvs(_user, poolToken, evoq.supplyBalanceInOf(poolToken, _user).onPool);

            _updateBorrowIndex(poolToken);
            unclaimedRewards += _accrueBorrowerXvs(_user, poolToken, evoq.borrowBalanceInOf(poolToken, _user).onPool);

            unchecked {
                ++i;
            }
        }

        userUnclaimedXvsRewards[_user] = unclaimedRewards;
    }

    /// @notice Updates supplier index and returns the accrued XVS rewards of the supplier since the last update.
    /// @param _supplier The address of the supplier.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function _accrueSupplierXvs(address _supplier, address _poolToken, uint256 _balance) internal returns (uint256) {
        uint256 supplyIndex = localXvsSupplyState[_poolToken].index;
        uint256 supplierIndex = venusSupplierIndex[_poolToken][_supplier];
        venusSupplierIndex[_poolToken][_supplier] = supplyIndex;

        if (supplierIndex == 0) return 0;
        return (_balance * (supplyIndex - supplierIndex)) / 1e36;
    }

    /// @notice Updates borrower index and returns the accrued XVS rewards of the borrower since the last update.
    /// @param _borrower The address of the borrower.
    /// @param _poolToken The vToken address.
    /// @param _balance The user balance of tokens in the distribution.
    /// @return The accrued XVS rewards.
    function _accrueBorrowerXvs(address _borrower, address _poolToken, uint256 _balance) internal returns (uint256) {
        uint256 borrowIndex = localXvsBorrowState[_poolToken].index;
        uint256 borrowerIndex = venusBorrowerIndex[_poolToken][_borrower];
        venusBorrowerIndex[_poolToken][_borrower] = borrowIndex;

        if (borrowerIndex == 0) return 0;
        return (_balance * (borrowIndex - borrowerIndex)) / 1e36;
    }

    /// @notice Updates the XVS supply index.
    /// @param _poolToken The vToken address.
    function _updateSupplyIndex(address _poolToken) internal {
        IComptroller.VenusMarketState storage localSupplyState = localXvsSupplyState[_poolToken];

        if (localSupplyState.block == block.number) {
            return;
        } else {
            IComptroller.VenusMarketState memory supplyState = comptroller.venusSupplyState(_poolToken);

            uint256 deltaBlocks = block.number - supplyState.block;
            uint256 supplySpeed = comptroller.venusSupplySpeeds(_poolToken);

            uint224 newXvsSupplyIndex;
            if (deltaBlocks > 0 && supplySpeed > 0) {
                uint256 supplyTokens = IVToken(_poolToken).totalSupply();
                uint256 xvsAccrued = deltaBlocks * supplySpeed;
                uint256 ratio = supplyTokens > 0 ? (xvsAccrued * 1e36) / supplyTokens : 0;

                newXvsSupplyIndex = uint224(supplyState.index + ratio);
            } else {
                newXvsSupplyIndex = supplyState.index;
            }

            localXvsSupplyState[_poolToken] =
                IComptroller.VenusMarketState({index: newXvsSupplyIndex, block: block.number.toUint32()});
        }
    }

    /// @notice Updates the XVS borrow index.
    /// @param _poolToken The vToken address.
    function _updateBorrowIndex(address _poolToken) internal {
        IComptroller.VenusMarketState storage localBorrowState = localXvsBorrowState[_poolToken];

        if (localBorrowState.block == block.number) {
            return;
        } else {
            IComptroller.VenusMarketState memory borrowState = comptroller.venusBorrowState(_poolToken);

            uint256 deltaBlocks = block.number - borrowState.block;
            uint256 borrowSpeed = comptroller.venusBorrowSpeeds(_poolToken);

            uint224 newXvsBorrowIndex;
            if (deltaBlocks > 0 && borrowSpeed > 0) {
                IVToken vToken = IVToken(_poolToken);

                uint256 borrowAmount = vToken.totalBorrows().div(vToken.borrowIndex());
                uint256 xvsAccrued = deltaBlocks * borrowSpeed;
                uint256 ratio = borrowAmount > 0 ? (xvsAccrued * 1e36) / borrowAmount : 0;

                newXvsBorrowIndex = uint224(borrowState.index + ratio);
            } else {
                newXvsBorrowIndex = borrowState.index;
            }

            localXvsBorrowState[_poolToken] =
                IComptroller.VenusMarketState({index: newXvsBorrowIndex, block: block.number.toUint32()});
        }
    }
}
