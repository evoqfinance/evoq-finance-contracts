// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import {IWBNB} from "src/interfaces/IWBNB.sol";
import {IEvoq} from "src/interfaces/IEvoq.sol";
import {IWBNBGateway} from "src/interfaces/extensions/IWBNBGateway.sol";

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";

/// @title WBNBGateway
/// @author Evoq Labs
/// @custom:contact info@evoq.finance
/// @notice A contract allowing to wrap and unwrap BNB when interacting with Evoq.
contract WBNBGateway is IWBNBGateway {
    using SafeTransferLib for ERC20;

    /* ERRORS */

    /// @notice Thrown when another address than WBNB sends BNB to the contract.
    error OnlyWBNB();

    /// @notice Thrown when the `evoq` address passed in the constructor is zero.
    error AddressIsZero();

    /// @notice Thrown when the amount used is zero.
    error AmountIsZero();

    /* IMMUTABLES */

    /// @dev The address of the Evoq protocol.
    IEvoq internal immutable _EVOQ;
    address internal immutable _WBNB;
    address internal immutable _VBNB;
    address internal immutable _EVOQ_TREASURY;

    /* CONSTRUCTOR */

    /// @notice Contract constructor.
    /// @param evoq The address of the Evoq protocol.
    constructor(address evoq, address wbnb, address vbnb, address treasury) {
        if (evoq == address(0)) revert AddressIsZero();

        _EVOQ = IEvoq(evoq);
        _WBNB = wbnb;
        ERC20(_WBNB).safeApprove(evoq, type(uint256).max);
        _VBNB = vbnb;
        _EVOQ_TREASURY = treasury;
    }

    /* EXTERNAL */

    /// @notice Returns the address of the WBNB contract.
    function WBNB() external view returns (address) {
        return _WBNB;
    }

    /// @notice Returns the address of the WBNB contract.
    function VBNB() external view returns (address) {
        return _VBNB;
    }

    /// @notice Returns the address of the Evoq protocol.
    function EVOQ() external view returns (address) {
        return address(_EVOQ);
    }

    /// @notice Returns the address of the Evoq Treasury.
    function EVOQ_TREASURY() external view returns (address) {
        return _EVOQ_TREASURY;
    }

    /// @notice Transfers this contract's given ERC20 balance to the Evoq Treasury, to avoid having funds stuck.
    function skim(address underlying) external {
        ERC20(underlying).safeTransfer(_EVOQ_TREASURY, ERC20(underlying).balanceOf(address(this)));
    }

    /// @notice Wraps `msg.value` BNB in WBNB and supplies them to Evoq on behalf of `onBehalf`.
    /// @return The actual amount supplied (in wei).
    function supplyBNB(address onBehalf) external payable returns (uint256) {
        _wrapBNB(msg.value);

        return _EVOQ.supply(_VBNB, onBehalf, msg.value);
    }

    /// @notice Borrows WBNB on behalf of `msg.sender`, unwraps the BNB and sends them to `receiver`.
    ///         Note: `msg.sender` must have approved this contract to be its manager.
    /// @return borrowed The actual amount borrowed (in wei).
    function borrowBNB(uint256 amount, address receiver) external returns (uint256 borrowed) {
        borrowed = _EVOQ.borrow(_VBNB, amount, msg.sender, address(this));
        _unwrapAndTransferBNB(borrowed, receiver);
    }

    /// @notice Wraps `msg.value` BNB in WBNB and repays `onBehalf`'s debt on Evoq.
    /// @return repaid The actual amount repaid (in wei).
    function repayBNB(address onBehalf) external payable returns (uint256 repaid) {
        _wrapBNB(msg.value);

        repaid = _EVOQ.repay(_VBNB, onBehalf, msg.value);

        uint256 excess = msg.value - repaid;
        if (excess > 0) _unwrapAndTransferBNB(excess, msg.sender);
    }

    /// @notice Withdraws WBNB up to `amount` on behalf of `msg.sender`, unwraps it to WBNB and sends it to `receiver`.
    ///         Note: `msg.sender` must have approved this contract to be its manager.
    /// @return withdrawn The actual amount withdrawn (in wei).
    function withdrawBNB(uint256 amount, address receiver) external returns (uint256 withdrawn) {
        withdrawn = _EVOQ.withdraw(_VBNB, amount, msg.sender, address(this));
        _unwrapAndTransferBNB(withdrawn, receiver);
    }

    /// @dev Only the WBNB contract is allowed to transfer BNB to this contracts.
    receive() external payable {
        if (msg.sender != _WBNB) revert OnlyWBNB();
    }

    /// @notice Transfers the BNB balance of this contract to the given address.
    function rescueBNB() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "No BNB to rescue");
        (bool success,) = _EVOQ_TREASURY.call{value: balance}("");
        require(success, "Transfer failed");
    }

    /* INTERNAL */

    /// @dev Wraps `amount` of BNB to WBNB.
    function _wrapBNB(uint256 amount) internal {
        if (amount == 0) revert AmountIsZero();
        IWBNB(_WBNB).deposit{value: amount}();
    }

    /// @dev Unwraps `amount` of WBNB to BNB and transfers it to `receiver`.
    function _unwrapAndTransferBNB(uint256 amount, address receiver) internal {
        if (amount == 0) revert AmountIsZero();
        IWBNB(_WBNB).withdraw(amount);
        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}
