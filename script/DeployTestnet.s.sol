// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/interfaces/IRewardsManager.sol";
import "src/interfaces/IInterestRatesManager.sol";
import "src/interfaces/IPositionsManager.sol";
import "src/interfaces/venus/IVenus.sol";
import "src/interfaces/extensions/IWBNBGateway.sol";

import "solmate/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades, UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {RewardsManager} from "src/RewardsManager.sol";
import {InterestRatesManager} from "src/InterestRatesManager.sol";
import {PositionsManager} from "src/PositionsManager.sol";
import {Evoq} from "src/Evoq.sol";
import {Lens} from "src/lens/Lens.sol";
import {DataLens} from "src/lens/DataLens.sol";
import {WBNBGateway} from "src/extensions/WBNBGateway.sol";
import {SimplePriceOracle} from "../test/helpers/SimplePriceOracle.sol";

import "config/venus/ConfigTestnet.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract Deploy is Script, ConfigTestnet {
    using SafeTransferLib for ERC20;

    function run() external {
        address comptroller = address(0x7d5785D151630F90F1Af60C009440D022a2eB2dA);

        vm.label(comptroller, "Comptroller");
        vm.label(vBnb, "vBNB");
        vm.label(vBtc, "vBTC");
        vm.label(vUsdt, "vUSDT");
        vm.label(vUsdc, "vUSDC");
        vm.label(vEth, "vETH");
        vm.label(vFdusd, "vFDUSD");
        vm.label(wBnb, "wBNB");

        vm.startBroadcast();

        // Deploy Evoq's dependencies
        interestRatesManager = new InterestRatesManager();
        positionsManager = new PositionsManager();

        // Deploy Evoq
        bytes memory initData = abi.encodeWithSelector(
            Evoq.initialize.selector,
            positionsManager,
            interestRatesManager,
            IComptroller(comptroller),
            Types.MaxGasForMatching({supply: 3e6, borrow: 3e6, withdraw: 3e6, repay: 3e6}),
            1,
            16,
            vBnb,
            wBnb
        );

        console.log("Deploying Evoq...");

        address owner = 0x7Bd1f59bB026e0aa948f9fDC2d4890179a21406d;
        evoqProxy = TransparentUpgradeableProxy(
            payable(Upgrades.deployTransparentProxy("Evoq.sol:Evoq", owner, initData))
        );

        console.log("Evoq deployed at:", address(evoqProxy));

        evoq = Evoq(payable(evoqProxy));

        IComptroller comptrollerInterface = IComptroller(address(0x7d5785D151630F90F1Af60C009440D022a2eB2dA));
        try comptrollerInterface.supportMarket(vBnb) {
            console.log("Market supported successfully");
        } catch Error(string memory reason) {
            console.log("Error:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Low level error:");
        }
        comptrollerInterface.supportMarket(vBtc);
        comptrollerInterface.supportMarket(vUsdt);
        comptrollerInterface.supportMarket(vUsdc);
        comptrollerInterface.supportMarket(vEth);
        comptrollerInterface.supportMarket(vFdusd);

        Types.MarketParameters memory defaultMarketParameters = Types.MarketParameters({
            reserveFactor: 0,
            p2pIndexCursor: 4_000
        });

        evoq.createMarket(vBnb, defaultMarketParameters);
        evoq.createMarket(vBtc, defaultMarketParameters);
        evoq.createMarket(vUsdt, defaultMarketParameters);
        evoq.createMarket(vUsdc, defaultMarketParameters);
        evoq.createMarket(vEth, defaultMarketParameters);
        evoq.createMarket(vFdusd, defaultMarketParameters);
        // Deploy RewardsManager
        rewardsManagerProxy = TransparentUpgradeableProxy(
            payable(Upgrades.deployTransparentProxy("RewardsManager.sol:RewardsManager", msg.sender, ""))
        );
        rewardsManager = RewardsManager(address(rewardsManagerProxy));
        rewardsManager.initialize(address(evoq));

        evoq.setRewardsManager(IRewardsManager(address(rewardsManager)));

        // Deploy Lens
        lensExtension = new LensExtension(address(evoq));
        lens = new Lens(address(lensExtension));
        dataLens = new DataLens(address(lens));

        // Deploy Treasury
        treasury = new Treasury();
        evoq.setTreasuryVault(address(treasury));
        evoq.setTreasuryPercentMantissa(0.05 ether); // 5%

        // Set market supply and borrow caps
        address[] memory markets = new address[](6);
        markets[0] = vBnb;
        markets[1] = vBtc;
        markets[2] = vUsdt;
        markets[3] = vUsdc;
        markets[4] = vEth;
        markets[5] = vFdusd;

        uint256[] memory supplyCaps = new uint256[](6);
        supplyCaps[0] = evoqSupplyCaps[vBnb];
        supplyCaps[1] = evoqSupplyCaps[vBtc];
        supplyCaps[2] = evoqSupplyCaps[vUsdt];
        supplyCaps[3] = evoqSupplyCaps[vUsdc];
        supplyCaps[4] = evoqSupplyCaps[vEth];
        supplyCaps[5] = evoqSupplyCaps[vFdusd];

        uint256[] memory borrowCaps = new uint256[](6);
        borrowCaps[0] = evoqBorrowCaps[vBnb];
        borrowCaps[1] = evoqBorrowCaps[vBtc];
        borrowCaps[2] = evoqBorrowCaps[vUsdt];
        borrowCaps[3] = evoqBorrowCaps[vUsdc];
        borrowCaps[4] = evoqBorrowCaps[vEth];
        borrowCaps[5] = evoqBorrowCaps[vFdusd];

        uint8[] memory capModes = new uint8[](6);
        capModes[0] = 1;
        capModes[1] = 1;
        capModes[2] = 1;
        capModes[3] = 1;
        capModes[4] = 1;
        capModes[5] = 1;

        evoq.setMarketSupplyCaps(markets, supplyCaps);
        evoq.setMarketBorrowCaps(markets, borrowCaps);
        evoq.setMarketCapModes(markets, capModes);

        wbnbGateway = new WBNBGateway(address(evoq), wBnb, vBnb, address(treasury));

        address currentComptroller = address(evoq.comptroller());
        console.log("Current Comptroller:", currentComptroller);

        vm.stopBroadcast();
    }
}
