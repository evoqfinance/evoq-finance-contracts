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
    address public constant wBnb = 0x832a7DffD8FD492886DfF2fe7B062c0490009b41;
    address public constant btcb = 0x78e2A49122128bC04e9d445F881297B11e64eE7D;
    address public constant usdt = 0xC7Bf79a4abE92243E4794FF6a4Ea0f9C0FcBfc8B;
    address public constant usdc = 0xE9071FD2d0C84A1302b19FBa37b689e833320008;
    address public constant eth = 0x98f7A83361F7Ac8765CcEBAB1425da6b341958a7;
    address public constant wbeth = 0xf9F98365566F4D55234f24b99caA1AfBE6428D44;
    address public constant fdusd = 0xcF27439fA231af9931ee40c4f27Bb77B83826F3C;
    address public constant cake = 0xe8bd7cCC165FAEb9b81569B05424771B9A20cbEF;
    address public constant xvs = 0xB9e0E753630434d7863528cc73CB7AC638a7c8ff;
    address public constant matic = 0xcfeb0103d4BEfa041EA4c2dACce7B3E83E1aE7E3;

    address public constant vBnb = 0xb24DEcC60D580e4040A6eC2F820455a6c02dFdC3;
    address public constant vBtc = 0x7E122784Ed346abF21536e3c1E2be2B47Fb619eb;
    address public constant vUsdt = 0x213966030BFAFa3C9Ea9fca87BCA2d51981E4975;
    address public constant vUsdc = 0x39f40402E11772B56B8b334153D99d2F1cc10ce5;
    address public constant vEth = 0x162D005F0Fff510E54958Cfc5CF32A3180A84aab;
    address public constant vWbeth = 0x35566ED3AF9E537Be487C98b1811cDf95ad0C32b;
    address public constant vFdusd = 0xF06e662a00796c122AaAE935EC4F0Be3F74f5636;
    address public constant vCake = 0xeDaC03D29ff74b5fDc0CC936F6288312e1459BC6;
    address public constant vXvs = 0x6d6F697e34145Bb95c54E77482d97cc261Dc237E;
    address public constant vMatic = 0x3619bdDc61189F33365CC572DF3a68FB3b316516;

    IVenusOracle public bnbOracle = IVenusOracle(0xcA6362339c5A6F5DA506E0B79ea34ABE8C6b8DE2);
    IVenusOracle public btcbOracle = IVenusOracle(0x15022478BD09Df28715D8755f0FA7C1a7e6B7D5a);
    IVenusOracle public usdtOracle = IVenusOracle(0xd7422eaB46231a8DcE398Cd178362F6A20C97575);
    IVenusOracle public usdcOracle = IVenusOracle(0x0C2D92688d36eF2219F4DDBAA4bbeDAc61467DD7);

    address public constant comptroller = 0x7d5785D151630F90F1Af60C009440D022a2eB2dA; // Deployed MockComptroller

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