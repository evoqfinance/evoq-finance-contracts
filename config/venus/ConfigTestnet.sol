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
    address constant wBnb = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address constant btcb = 0xA808e341e8e723DC6BA0Bb5204Bafc2330d7B8e4;
    address constant usdt = 0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c;
    address constant usdc = 0x16227D60f7a0e586C66B005219dfc887D13C9531;
    address constant eth = 0x98f7A83361F7Ac8765CcEBAB1425da6b341958a7;
    address constant wbeth = 0xf9F98365566F4D55234f24b99caA1AfBE6428D44;
    address constant fdusd = 0xcF27439fA231af9931ee40c4f27Bb77B83826F3C;
    address constant cake = 0xe8bd7cCC165FAEb9b81569B05424771B9A20cbEF;
    address constant xvs = 0xB9e0E753630434d7863528cc73CB7AC638a7c8ff;
    address constant matic = 0xcfeb0103d4BEfa041EA4c2dACce7B3E83E1aE7E3;

    address constant vBnb = 0x2E7222e51c0f6e98610A1543Aa3836E092CDe62c;
    address constant vBtc = 0xb6e9322C49FD75a367Fcb17B0Fcd62C5070EbCBe;
    address constant vUsdt = 0xb7526572FFE56AB9D7489838Bf2E18e3323b441A;
    address constant vUsdc = 0xD5C4C2e2facBEB59D0216D0595d63FcDc6F9A1a7;
    address constant vEth = 0x162D005F0Fff510E54958Cfc5CF32A3180A84aab;
    address constant vWbeth = 0x35566ED3AF9E537Be487C98b1811cDf95ad0C32b;
    address constant vFdusd = 0xF06e662a00796c122AaAE935EC4F0Be3F74f5636;
    address constant vCake = 0xeDaC03D29ff74b5fDc0CC936F6288312e1459BC6;
    address constant vXvs = 0x6d6F697e34145Bb95c54E77482d97cc261Dc237E;
    address constant vMatic = 0x3619bdDc61189F33365CC572DF3a68FB3b316516;

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
