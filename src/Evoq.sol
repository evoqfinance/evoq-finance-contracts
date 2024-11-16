// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "./EvoqGovernance.sol";

/// @title Evoq.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice Main Evoq contract handling user interactions and pool interactions.
contract Evoq is EvoqGovernance {
    using SafeTransferLib for ERC20;
    using DelegateCall for address;

    /// EVENTS ///

    /// @notice Emitted when a user claims rewards.
    /// @param _user The address of the claimer.
    /// @param _amountClaimed The amount of reward token claimed.
    /// @param _traded Whether or not the pool tokens are traded against Evoq tokens.
    event RewardsClaimed(address indexed _user, uint256 _amountClaimed, bool indexed _traded);

    /// ERRORS ///

    /// @notice Thrown when claiming rewards is paused.
    error ClaimRewardsPaused();

    /// EXTERNAL ///

    /// @notice Supplies underlying tokens to a specific market.
    /// @dev `msg.sender` must have approved Evoq's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying) to supply.
    function supply(address _poolToken, uint256 _amount) external nonReentrant returns (uint256) {
        return _supply(_poolToken, msg.sender, _amount, defaultMaxGasForMatching.supply);
    }

    /// @notice Supplies underlying tokens to a specific market, on behalf of a given user.
    /// @dev `msg.sender` must have approved Evoq's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to supply.
    function supply(address _poolToken, address _onBehalf, uint256 _amount) external nonReentrant returns (uint256) {
        return _supply(_poolToken, _onBehalf, _amount, defaultMaxGasForMatching.supply);
    }

    /// @notice Supplies underlying tokens to a specific market, on behalf of a given user,
    ///         specifying a gas threshold at which to cut the matching engine.
    /// @dev `msg.sender` must have approved Evoq's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to supply.
    /// @param _maxGasForMatching The gas threshold at which to stop the matching engine.
    function supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        nonReentrant
        returns (uint256)
    {
        return _supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);
    }

    /// @notice Borrows underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying).
    function borrow(address _poolToken, uint256 _amount) external nonReentrant returns (uint256) {
        return _borrow(_poolToken, _amount, msg.sender, msg.sender, defaultMaxGasForMatching.borrow);
    }

    /// @notice Borrows underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying).
    /// @param _borrower The address of the account borrowing the tokens.
    /// @param _receiver The address to send borrowed tokens to.
    function borrow(address _poolToken, uint256 _amount, address _borrower, address _receiver)
        external
        nonReentrant
        returns (uint256)
    {
        return _borrow(_poolToken, _amount, _borrower, _receiver, defaultMaxGasForMatching.borrow);
    }

    /// @notice Borrows underlying tokens from a specific market, specifying a gas threshold at which to stop the matching engine.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying).
    /// @param _borrower The address of the account borrowing the tokens.
    /// @param _receiver The address to send borrowed tokens to.
    /// @param _maxGasForMatching The gas threshold at which to stop the matching engine.
    function borrow(
        address _poolToken,
        uint256 _amount,
        address _borrower,
        address _receiver,
        uint256 _maxGasForMatching
    ) external nonReentrant returns (uint256) {
        return _borrow(_poolToken, _amount, _borrower, _receiver, _maxGasForMatching);
    }

    /// @notice Withdraws underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of tokens (in underlying) to withdraw from supply.
    function withdraw(address _poolToken, uint256 _amount) external nonReentrant returns (uint256) {
        return _withdraw(_poolToken, _amount, msg.sender, msg.sender, defaultMaxGasForMatching.withdraw);
    }

    /// @notice Withdraws underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of tokens (in underlying) to withdraw from supply.
    /// @param _receiver The address to send withdrawn tokens to.
    function withdraw(address _poolToken, uint256 _amount, address _supplier, address _receiver)
        external
        nonReentrant
        returns (uint256)
    {
        return _withdraw(_poolToken, _amount, _supplier, _receiver, defaultMaxGasForMatching.withdraw);
    }

    /// @notice Repays the debt of the sender, up to the amount provided.
    /// @dev `msg.sender` must have approved Evoq's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying) to repay from borrow.
    function repay(address _poolToken, uint256 _amount) external nonReentrant returns (uint256) {
        return _repay(_poolToken, msg.sender, msg.sender, _amount, defaultMaxGasForMatching.repay);
    }

    /// @notice Repays debt of a given user, up to the amount provided.
    /// @dev `msg.sender` must have approved Evoq's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to repay from borrow.
    function repay(address _poolToken, address _onBehalf, uint256 _amount) external nonReentrant returns (uint256) {
        return _repay(_poolToken, msg.sender, _onBehalf, _amount, defaultMaxGasForMatching.repay);
    }

    /// @notice Liquidates a position.
    /// @param _poolTokenBorrowed The address of the pool token the liquidator wants to repay.
    /// @param _poolTokenCollateral The address of the collateral pool token the liquidator wants to seize.
    /// @param _borrower The address of the borrower to liquidate.
    /// @param _amount The amount of token (in underlying) to repay.
    function liquidate(address _poolTokenBorrowed, address _poolTokenCollateral, address _borrower, uint256 _amount)
        external
        nonReentrant
        returns (uint256, uint256)
    {
        bytes memory returnData = address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.liquidateLogic.selector, _poolTokenBorrowed, _poolTokenCollateral, _borrower, _amount
            )
        );
        return (abi.decode(returnData, (uint256, uint256)));
    }

    /// @notice Claims rewards for the given assets.
    /// @param _vTokenAddresses The vToken addresses to claim rewards from.
    /// @return amountOfRewards The amount of rewards claimed (in XVS).
    function claimRewards(address[] calldata _vTokenAddresses)
        external
        nonReentrant
        returns (uint256 amountOfRewards)
    {
        if (isClaimRewardsPaused) revert ClaimRewardsPaused();
        amountOfRewards = rewardsManager.claimRewards(_vTokenAddresses, msg.sender);

        if (amountOfRewards > 0) {
            comptroller.claimVenus(address(this), _vTokenAddresses);
            ERC20(comptroller.getXVSAddress()).safeTransfer(msg.sender, amountOfRewards);

            emit RewardsClaimed(msg.sender, amountOfRewards, false);
        }
    }

    /// @notice Allows to receive BNB.
    receive() external payable {}

    /// INTERNAL ///

    function _supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        internal
        returns (uint256)
    {
        bytes memory returnData = address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.supplyLogic.selector, _poolToken, msg.sender, _onBehalf, _amount, _maxGasForMatching
            )
        );
        return (abi.decode(returnData, (uint256)));
    }

    function _borrow(
        address _poolToken,
        uint256 _amount,
        address _borrower,
        address _receiver,
        uint256 _maxGasForMatching
    ) internal returns (uint256) {
        bytes memory returnData = address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.borrowLogic.selector, _poolToken, _amount, _borrower, _receiver, _maxGasForMatching
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _withdraw(
        address _poolToken,
        uint256 _amount,
        address _supplier,
        address _receiver,
        uint256 _maxGasForMatching
    ) internal returns (uint256) {
        bytes memory returnData = address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.withdrawLogic.selector, _poolToken, _amount, _supplier, _receiver, _maxGasForMatching
            )
        );
        return (abi.decode(returnData, (uint256)));
    }

    function _repay(
        address _poolToken,
        address _repayer,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) internal returns (uint256) {
        bytes memory returnData = address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.repayLogic.selector, _poolToken, _repayer, _onBehalf, _amount, _maxGasForMatching
            )
        );
        return (abi.decode(returnData, (uint256)));
    }
}
