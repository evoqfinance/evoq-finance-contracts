// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import "../interfaces/venus/IVenus.sol";
import "./interfaces/ILensExtension.sol";
import "../interfaces/IEvoq.sol";
import "./interfaces/ILens.sol";

import "morpho-utils/math/CompoundMath.sol";
import "../libraries/InterestRatesModel.sol";
import "morpho-utils/math/Math.sol";
import "morpho-utils/math/PercentageMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title LensStorage.
/// @author Evoq Finance.
/// @custom:contact info@evoq.finance
/// @notice Base layer to the Evoq Protocol Lens, managing the upgradeable storage layout.
abstract contract LensStorage is ILens, Initializable {
    /// CONSTANTS ///

    uint256 public constant MAX_BASIS_POINTS = 100_00; // 100% (in basis points).
    uint256 public constant WAD = 1e18;

    /// IMMUTABLES ///

    IEvoq public immutable evoq;
    IComptroller public immutable comptroller;
    IRewardsManager public immutable rewardsManager;
    ILensExtension internal immutable lensExtension;

    /// CONSTRUCTOR ///

    /// @notice Constructs the contract.
    /// @param _lensExtension The address of the Lens extension.
    constructor(address _lensExtension) {
        lensExtension = ILensExtension(_lensExtension);
        evoq = IEvoq(lensExtension.evoq());
        comptroller = IComptroller(evoq.comptroller());
        rewardsManager = IRewardsManager(evoq.rewardsManager());
    }
}
