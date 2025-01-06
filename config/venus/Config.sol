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

contract Config is BaseConfig {
    address constant vBnb = 0xA07c5b74C9B40447a954e1466938b865b6BBea36;
    address constant vBtc = 0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B;
    address constant vUsdt = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    address constant vUsdc = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
    address constant vEth = 0xf508fCD89b8bd15579dc79A6827cB4686A3592c8;
    address constant vWbeth = 0x6CFdEc747f37DAf3b87a35a1D9c8AD3063A1A8A0;
    address constant vFdusd = 0xC4eF4229FEc74Ccfe17B2bdeF7715fAC740BA0ba;
    address constant vCake = 0x86aC3974e2BD0d60825230fa6F355fF11409df5c;
    address constant vXvs = 0x151B1e2635A717bcDc836ECd6FbB62B674FE3E1D;

    address constant vDot = 0x1610bc33319e9398de5f57B33a5b184c806aD217;
    address constant vDai = 0x334b3eCB4DCa3593BCCC3c7EBD1A1C1d1780FBF1;
    address constant vMatic = 0x5c9476FcD6a4F9a3654139721c949c2233bBbBc8;

    IComptroller public comptroller = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
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
