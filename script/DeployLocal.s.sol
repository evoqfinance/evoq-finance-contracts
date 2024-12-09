// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

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

import "config/venus/Config.sol";
import "forge-std/Script.sol";

contract Deploy is Script, Config {
    using SafeTransferLib for ERC20;

    function run() external {
        vm.label(address(comptroller), "Comptroller");
        vm.label(vBnb, "vBNB");
        vm.label(vBtc, "vBTC");
        vm.label(vUsdt, "vUSDT");
        vm.label(vUsdc, "vUSDC");
        vm.label(vEth, "vETH");
        vm.label(vWbeth, "vWBETH");
        vm.label(vFdusd, "vFDUSD");
        vm.label(vCake, "vCAKE");
        vm.label(wBnb, "wBNB");

        vm.startBroadcast();

        // Deploy Evoq's dependencies
        interestRatesManager = new InterestRatesManager();
        positionsManager = new PositionsManager();

        // Deploy Evoq
        evoqProxy =
            TransparentUpgradeableProxy(payable(Upgrades.deployTransparentProxy("Evoq.sol:Evoq", msg.sender, "")));

        evoq = Evoq(payable(evoqProxy));
        evoq.initialize(
            positionsManager,
            interestRatesManager,
            comptroller,
            Types.MaxGasForMatching({supply: 3e6, borrow: 3e6, withdraw: 3e6, repay: 3e6}),
            1,
            16,
            vBnb,
            wBnb
        );

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

        // Create markets
        Types.MarketParameters memory defaultMarketParameters =
            Types.MarketParameters({reserveFactor: 1_000, p2pIndexCursor: 4_000});
        evoq.createMarket(vBnb, defaultMarketParameters);
        evoq.createMarket(vUsdc, defaultMarketParameters);
        evoq.createMarket(vEth, defaultMarketParameters);
        evoq.createMarket(vXvs, defaultMarketParameters);
        evoq.createMarket(vMatic, defaultMarketParameters);
        // NOTE: add more markets, cause SimplePriceOracle to change address.
        // Changes affect frontend and script/.

        // Set market supply and borrow caps
        address[] memory markets = new address[](5);
        markets[0] = vBnb;
        markets[1] = vUsdc;
        markets[2] = vEth;
        markets[3] = vXvs;
        markets[4] = vMatic;

        uint256[] memory supplyCaps = new uint256[](5);
        supplyCaps[0] = 2_672_000 ether;
        supplyCaps[1] = 258_000_000 ether;
        supplyCaps[2] = 100_000 ether;
        supplyCaps[3] = 1_850_000 ether;
        supplyCaps[4] = 5_500_000 ether;

        uint256[] memory borrowCaps = new uint256[](5);
        borrowCaps[0] = 2_008_000 ether;
        borrowCaps[1] = 200_000_000 ether;
        borrowCaps[2] = 60_000 ether;
        borrowCaps[3] = 0 ether;
        borrowCaps[4] = 250_000 ether;

        evoq.setMarketSupplyCaps(markets, supplyCaps);
        evoq.setMarketBorrowCaps(markets, borrowCaps);

        IWBNBGateway wbnbGateway = new WBNBGateway(address(evoq), vBnb);

        // ====== DEV ==========

        // setup fake price oracle for local dev, because mainnet oracle is too strict with the price fetching
        address[] memory pools = evoq.getAllMarkets();
        SimplePriceOracle customOracle = new SimplePriceOracle();
        for (uint256 i = 0; i < pools.length; i++) {
            customOracle.setUnderlyingPrice(pools[i], oracle.getUnderlyingPrice(pools[i]));
        }

        // Init some value for development
        // WBNB(wBnb).deposit{value: 1000 ether}(); // get wBNB

        // approve(usdc, address(evoq), type(uint256).max);
        // evoq.supply(vUsdc, 1000 ether);
        // evoq.borrow(vUsdt, 500 ether);

        // approve(wBnb, address(evoq), type(uint256).max);
        // evoq.supply(vBnb, 1000 ether);
        // evoq.borrow(vBtc, 0.2 ether);

        vm.stopBroadcast();
    }

    function approve(address _token, address _spender, uint256 _amount) internal {
        ERC20(_token).safeApprove(_spender, _amount);
    }
}

interface WBNB {
    function deposit() external payable;
}
