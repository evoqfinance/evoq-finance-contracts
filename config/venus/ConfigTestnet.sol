// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "src/interfaces/venus/IVenus.sol";
import {IPositionsManager} from "src/interfaces/IPositionsManager.sol";
import {IInterestRatesManager} from "src/interfaces/IInterestRatesManager.sol";
import {IEvoq} from "src/interfaces/IEvoq.sol";

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {RewardsManager} from "src/RewardsManager.sol";
import {LensExtension} from "src/lens/LensExtension.sol";
import {Lens} from "src/lens/Lens.sol";
import {DataLens} from "src/lens/DataLens.sol";
import {IDataLens} from "src/lens/interfaces/IDataLens.sol";
import {Evoq} from "src/Evoq.sol";
import {Treasury} from "src/Treasury.sol";
import {WBNBGateway} from "src/extensions/WBNBGateway.sol";
import {BaseConfig} from "../BaseConfig.sol";
import "src/libraries/Types.sol";

contract ConfigTestnet {
    address constant wBnb = 0x832a7DffD8FD492886DfF2fe7B062c0490009b41;
    address constant btcb = 0x78e2A49122128bC04e9d445F881297B11e64eE7D;
    address constant usdt = 0xC7Bf79a4abE92243E4794FF6a4Ea0f9C0FcBfc8B;
    address constant usdc = 0xE9071FD2d0C84A1302b19FBa37b689e833320008;

    address constant vBnb = 0x7d4466a7ACF15b4f5e1D44D3380f5eFCC91Dd066;
    address constant vBtc = 0xb6e9322C49FD75a367Fcb17B0Fcd62C5070EbCBe;
    address constant vUsdt = 0xb7526572FFE56AB9D7489838Bf2E18e3323b441A;
    address constant vUsdc = 0xD5C4C2e2facBEB59D0216D0595d63FcDc6F9A1a7;

    IComptroller public comptroller = IComptroller(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D);
    IVenusOracle public oracle = IVenusOracle(comptroller.oracle());

    address public comptrollerAdmin = comptroller.admin(); // Timelock

    // Evoq
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public evoqProxy;
    TransparentUpgradeableProxy public rewardsManagerProxy;
    TransparentUpgradeableProxy public lensProxy;

    Lens public lensImplV1;
    Evoq public evoqImplV1;
    RewardsManager public rewardsManagerImplV1;

    Lens public lens;
    LensExtension public lensExtension;
    DataLens public dataLens;

    Evoq public evoq;
    RewardsManager public rewardsManager;
    IPositionsManager public positionsManager;
    IInterestRatesManager public interestRatesManager;
    Treasury public treasury;

    WBNBGateway public wbnbGateway;

    mapping(address => uint256) public evoqSupplyCaps;
    mapping(address => uint256) public evoqBorrowCaps;

    constructor() {
        evoqSupplyCaps[vBnb] = 2_672_000 ether;
        evoqSupplyCaps[vBtc] = 22_770 ether;
        evoqSupplyCaps[vUsdt] = 500_000_000 ether;
        evoqSupplyCaps[vUsdc] = 258_000_000 ether;
        evoqSupplyCaps[vEth] = 100_000 ether;
        evoqSupplyCaps[vFdusd] = 100_000_000 ether;

        evoqBorrowCaps[vBnb] = 2_008_000 ether;
        evoqBorrowCaps[vBtc] = 3_531 ether;
        evoqBorrowCaps[vUsdt] = 450_000_000 ether;
        evoqBorrowCaps[vUsdc] = 200_000_000 ether;
        evoqBorrowCaps[vEth] = 60_000 ether;
        evoqBorrowCaps[vFdusd] = 80_000_000 ether;
    }
}