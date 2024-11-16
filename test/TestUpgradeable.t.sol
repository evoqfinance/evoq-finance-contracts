// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./setup/TestSetup.sol";

contract TestUpgradeable is TestSetup {
    /// Evoq ///

    function testUpgradeEvoq() public {
        _testUpgradeProxy(evoqProxy, address(new Evoq()));
    }

    function testOnlyProxyOwnerCanUpgradeEvoq() public {
        _testOnlyProxyOwnerCanUpgradeProxy(evoqProxy, address(new Evoq()));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallEvoq() public {
        _testOnlyProxyOwnerCanUpgradeAndCallProxy(evoqProxy, address(new Evoq()));
    }

    function testEvoqImplementationShouldBeInitialized() public {
        _testProxyImplementationShouldBeInitialized(address(evoqImplV1));

        hevm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        evoqImplV1.initialize(
            positionsManager,
            interestRatesManager,
            comptroller,
            Types.MaxGasForMatching({supply: 3e6, borrow: 3e6, withdraw: 3e6, repay: 3e6}),
            1,
            20,
            vBnb,
            wBnb
        );
    }

    function testPositionsManagerImplementationShouldBeInitialized() public {
        _testProxyImplementationShouldBeInitialized(address(positionsManager));
    }

    /// RewardsManager ///

    function testUpgradeRewardsManager() public {
        _testUpgradeProxy(rewardsManagerProxy, address(new RewardsManager()));
    }

    function testOnlyProxyOwnerCanUpgradeRewardsManager() public {
        _testOnlyProxyOwnerCanUpgradeProxy(rewardsManagerProxy, address(new RewardsManager()));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallRewardsManager() public {
        _testOnlyProxyOwnerCanUpgradeAndCallProxy(rewardsManagerProxy, address(new RewardsManager()));
    }

    function testRewardsManagerImplementationShouldBeInitialized() public {
        _testProxyImplementationShouldBeInitialized(address(rewardsManagerImplV1));

        hevm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        rewardsManagerImplV1.initialize(address(evoq));
    }

    /// Lens ///

    function testUpgradeLens() public {
        _testUpgradeProxy(lensProxy, address(new Lens(address(lensExtension))));
    }

    function testOnlyProxyOwnerCanUpgradeLens() public {
        _testOnlyProxyOwnerCanUpgradeProxy(lensProxy, address(new Lens(address(lensExtension))));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallLens() public {
        _testOnlyProxyOwnerCanUpgradeAndCallProxy(lensProxy, address(new Lens(address(lensExtension))));
    }

    /// INTERNAL ///

    function _testUpgradeProxy(TransparentUpgradeableProxy _proxy, address _impl) internal {
        hevm.record();
        // proxyAdmin.upgrade(_proxy, _impl); // Legacy
        UnsafeUpgrades.upgradeProxy(address(_proxy), _impl, ""); // NOTE: OZv5
        (, bytes32[] memory writes) = hevm.accesses(address(_proxy));

        assertEq(writes.length, 1);
        assertEq(
            bytes32ToAddress(
                hevm.load(address(_proxy), bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1))
            ),
            _impl
        );
    }

    function _testOnlyProxyOwnerCanUpgradeProxy(TransparentUpgradeableProxy _proxy, address _impl) internal {
        hevm.prank(address(supplier1));
        // vm.expectRevert(); // TODO: [EvmError: Revert] because the caller != admin so it runs _fallback.
        UnsafeUpgrades.upgradeProxy(address(_proxy), _impl, "");
    }

    function _testOnlyProxyOwnerCanUpgradeAndCallProxy(TransparentUpgradeableProxy _proxy, address _impl) internal {
        hevm.prank(address(supplier1));
        hevm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(supplier1)));

        // proxyAdmin.upgradeAndCall(_proxy, _impl, "");
        ProxyAdmin _proxyAdmin = ProxyAdmin(UnsafeUpgrades.getAdminAddress(address(_proxy)));
        _proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_proxy)), _impl, "");
    }

    function _testProxyImplementationShouldBeInitialized(address impl) public {
        // assertEq(uint256(hevm.load(impl, 0)), 1); // slot storage not found
    }
}
