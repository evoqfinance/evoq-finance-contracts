// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/interfaces/IEvoq.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "morpho-utils/math/CompoundMath.sol";
import "solmate/utils/SafeTransferLib.sol";
import {Upgrades, UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {PositionsManager} from "src/PositionsManager.sol";
import {InterestRatesManager} from "src/InterestRatesManager.sol";
import {Treasury} from "src/Treasury.sol";
import "../helpers/EvoqToken.sol";
import "../helpers/SimplePriceOracle.sol";
import "../helpers/DumbOracle.sol";
import {User} from "../helpers/User.sol";
import {Utils} from "./Utils.sol";
import "config/venus/Config.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "forge-std/Vm.sol";

contract TestSetup is Config, Utils {
    Vm public hevm = Vm(VM_ADDRESS);

    uint256 public constant MAX_BASIS_POINTS = 10_000;
    uint256 public constant INITIAL_BALANCE = 1_000_000;

    DumbOracle public dumbOracle;
    EvoqToken public evoqToken;

    User public treasuryVault;

    User public supplier1;
    User public supplier2;
    User public supplier3;
    User[] public suppliers;

    User public borrower1;
    User public borrower2;
    User public borrower3;
    User[] public borrowers;

    address[] public pools;

    function setUp() public {
        initContracts();
        setContractsLabels();
        initUsers();

        onSetUp();
    }

    function onSetUp() public virtual {}

    function initContracts() internal {
        interestRatesManager = new InterestRatesManager();
        positionsManager = new PositionsManager();

        /// Deploy proxies ///

        evoqImplV1 = new Evoq();

        /* Legacy
        proxyAdmin = new ProxyAdmin();
        evoqProxy = new TransparentUpgradeableProxy(
            address(evoqImplV1),
            address(this),
            ""
        );
        evoqProxy.changeAdmin(address(proxyAdmin));
        */

        // NOTE: OZv5. ProxyAdmin is deployed in TransparentUpgradeableProxy.
        // see: https://docs.openzeppelin.com/upgrades-plugins/1.x/foundry-upgrades
        evoqProxy = TransparentUpgradeableProxy(
            payable(UnsafeUpgrades.deployTransparentProxy(address(evoqImplV1), address(this), ""))
        );

        evoq = Evoq(payable(address(evoqProxy)));
        evoq.initialize(
            positionsManager,
            interestRatesManager,
            comptroller,
            Types.MaxGasForMatching({supply: 3e6, borrow: 3e6, withdraw: 3e6, repay: 3e6}),
            1,
            20,
            vBnb,
            wBnb
        );

        wbnbGateway = new WBNBGateway(address(evoq), wBnb, vBnb, address(treasury));

        treasuryVault = new User(evoq, wbnbGateway);

        evoq.setTreasuryVault(address(treasuryVault));

        /// Create markets ///

        createMarket(vBnb);
        createMarket(vBtc);
        createMarket(vUsdt);
        createMarket(vUsdc);
        createMarket(vEth);
        createMarket(vWbeth);
        createMarket(vFdusd);
        createMarket(vDai);

        hevm.roll(block.number + 1);

        ///  Create Evoq token, deploy Incentives Vault and activate XVS rewards ///

        evoqToken = new EvoqToken(address(this));
        dumbOracle = new DumbOracle();

        rewardsManagerImplV1 = new RewardsManager();
        // rewardsManagerProxy = new TransparentUpgradeableProxy(
        //     address(rewardsManagerImplV1),
        //     address(proxyAdmin),
        //     ""
        // );
        rewardsManagerProxy = TransparentUpgradeableProxy(
            payable(UnsafeUpgrades.deployTransparentProxy(address(rewardsManagerImplV1), address(this), ""))
        );
        rewardsManager = RewardsManager(address(rewardsManagerProxy));
        rewardsManager.initialize(address(evoq));

        evoq.setRewardsManager(rewardsManager);

        lensExtension = new LensExtension(address(evoq));
        lensImplV1 = new Lens(address(lensExtension));
        // lensProxy = new TransparentUpgradeableProxy(
        //     address(lensImplV1),
        //     address(proxyAdmin),
        //     ""
        // );
        lensProxy = TransparentUpgradeableProxy(
            payable(UnsafeUpgrades.deployTransparentProxy(address(lensImplV1), address(this), ""))
        );
        lens = Lens(address(lensProxy));

        dataLens = new DataLens(address(lens));
    }

    function createMarket(address _vToken) internal {
        Types.MarketParameters memory marketParams = Types.MarketParameters(0, 3_333);
        evoq.createMarket(_vToken, marketParams);

        // All tokens must also be added to the pools array, for the correct behavior of TestLiquidate::createAndSetCustomPriceOracle.
        pools.push(_vToken);

        hevm.label(_vToken, ERC20(_vToken).symbol());
        if (_vToken == vBnb) {
            hevm.label(wBnb, "WBNB");
        } else {
            address underlying = IVToken(_vToken).underlying();
            hevm.label(underlying, ERC20(underlying).symbol());
        }

        // Set supply and borrow caps
        address[] memory markets = new address[](1);
        uint256[] memory supplyCaps = new uint256[](1);
        uint256[] memory borrowCaps = new uint256[](1);

        markets[0] = _vToken;
        supplyCaps[0] = type(uint256).max; // No supply cap
        borrowCaps[0] = type(uint256).max; // No borrow cap

        evoq.setMarketSupplyCaps(markets, supplyCaps);
        evoq.setMarketBorrowCaps(markets, borrowCaps);
    }

    function initUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers.push(new User(evoq, wbnbGateway));
            hevm.label(address(suppliers[i]), string(abi.encodePacked("Supplier", Strings.toString(i + 1))));
            fillUserBalances(suppliers[i]);
        }
        supplier1 = suppliers[0];
        supplier2 = suppliers[1];
        supplier3 = suppliers[2];

        for (uint256 i = 0; i < 3; i++) {
            borrowers.push(new User(evoq, wbnbGateway));
            hevm.label(address(borrowers[i]), string(abi.encodePacked("Borrower", Strings.toString(i + 1))));
            fillUserBalances(borrowers[i]);
        }

        borrower1 = borrowers[0];
        borrower2 = borrowers[1];
        borrower3 = borrowers[2];
    }

    function fillUserBalances(User _user) internal {
        // deal(address(_user), INITIAL_BALANCE * WAD);
        deal(wBnb, address(_user), INITIAL_BALANCE * WAD);
        deal(btcb, address(_user), INITIAL_BALANCE * WAD);
        deal(usdt, address(_user), INITIAL_BALANCE * WAD);
        deal(usdc, address(_user), INITIAL_BALANCE * WAD);
        deal(eth, address(_user), INITIAL_BALANCE * WAD);
        deal(wbeth, address(_user), INITIAL_BALANCE * WAD);
        deal(fdusd, address(_user), INITIAL_BALANCE * WAD);
        deal(cake, address(_user), INITIAL_BALANCE * WAD);
        deal(dai, address(_user), INITIAL_BALANCE * WAD);
    }

    function setContractsLabels() internal {
        hevm.label(address(proxyAdmin), "ProxyAdmin");
        hevm.label(address(evoqImplV1), "EvoqImplV1");
        hevm.label(address(evoq), "Evoq");
        hevm.label(address(interestRatesManager), "InterestRatesManager");
        hevm.label(address(rewardsManager), "RewardsManager");
        hevm.label(address(evoqToken), "EvoqToken");
        hevm.label(address(comptroller), "Comptroller");
        hevm.label(address(oracle), "VenusOracle");
        hevm.label(address(dumbOracle), "DumbOracle");
        hevm.label(address(treasuryVault), "TreasuryVault");
        hevm.label(address(lens), "Lens");
    }

    function createSigners(uint256 _nbOfSigners) internal {
        while (borrowers.length < _nbOfSigners) {
            borrowers.push(new User(evoq, wbnbGateway));
            fillUserBalances(borrowers[borrowers.length - 1]);
            hevm.label(
                address(borrowers[borrowers.length - 1]),
                string(abi.encodePacked("Borrower", Strings.toString(borrowers.length)))
            );
            suppliers.push(new User(evoq, wbnbGateway));
            fillUserBalances(suppliers[suppliers.length - 1]);
        }
    }

    function createAndSetCustomPriceOracle() public returns (SimplePriceOracle) {
        SimplePriceOracle customOracle = new SimplePriceOracle();

        IComptroller adminComptroller = IComptroller(address(comptroller));
        hevm.prank(adminComptroller.admin());
        uint256 result = adminComptroller._setPriceOracle(address(customOracle));
        require(result == 0); // No error

        for (uint256 i = 0; i < pools.length; i++) {
            customOracle.setUnderlyingPrice(pools[i], oracle.getUnderlyingPrice(pools[i]));
        }
        return customOracle;
    }

    function setDefaultMaxGasForMatchingHelper(uint64 _supply, uint64 _borrow, uint64 _withdraw, uint64 _repay)
        public
    {
        Types.MaxGasForMatching memory newMaxGas =
            Types.MaxGasForMatching({supply: _supply, borrow: _borrow, withdraw: _withdraw, repay: _repay});
        evoq.setDefaultMaxGasForMatching(newMaxGas);
    }

    function moveOneBlockForwardBorrowRepay() public {
        hevm.roll(block.number + 1);
    }

    function move1000BlocksForward(address _marketAddress) public {
        for (uint256 k; k < 100; k++) {
            hevm.roll(block.number + 10);
            hevm.warp(block.timestamp + 1);
            evoq.updateP2PIndexes(_marketAddress);
        }
    }

    function move100BlocksForward(address _marketAddress) public {
        for (uint256 k; k < 10; k++) {
            hevm.roll(block.number + 10);
            hevm.warp(block.timestamp + 1);
            evoq.updateP2PIndexes(_marketAddress);
        }
    }

    /// @notice Computes and returns peer-to-peer rates for a specific market (without taking into account deltas !).
    /// @param _poolToken The market address.
    /// @return p2pSupplyRate_ The market's supply rate in peer-to-peer (in wad).
    /// @return p2pBorrowRate_ The market's borrow rate in peer-to-peer (in wad).
    function getApproxP2PRates(address _poolToken)
        public
        view
        returns (uint256 p2pSupplyRate_, uint256 p2pBorrowRate_)
    {
        IVToken vToken = IVToken(_poolToken);

        uint256 poolSupplyBPY = vToken.supplyRatePerBlock();
        uint256 poolBorrowBPY = vToken.borrowRatePerBlock();
        (uint256 reserveFactor, uint256 p2pIndexCursor) = evoq.marketParameters(_poolToken);

        // rate = 2/3 * poolSupplyRate + 1/3 * poolBorrowRate.
        uint256 rate = ((10_000 - p2pIndexCursor) * poolSupplyBPY + p2pIndexCursor * poolBorrowBPY) / 10_000;

        p2pSupplyRate_ = rate - (reserveFactor * (rate - poolSupplyBPY)) / 10_000;
        p2pBorrowRate_ = rate + (reserveFactor * (poolBorrowBPY - rate)) / 10_000;
    }
}
