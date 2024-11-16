// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "src/interfaces/IRewardsManager.sol";
import "src/interfaces/extensions/IWBNBGateway.sol";

import "src/Evoq.sol";

contract User {
    using SafeTransferLib for ERC20;

    Evoq internal evoq;
    IRewardsManager internal rewardsManager;
    IComptroller internal comptroller;
    IWBNBGateway internal wbnbGateway;

    constructor(Evoq _evoq, IWBNBGateway _wbnbGateway) {
        evoq = _evoq;
        rewardsManager = _evoq.rewardsManager();
        comptroller = evoq.comptroller();
        wbnbGateway = _wbnbGateway;
    }

    receive() external payable {}

    function venusSupply(address _poolToken, uint256 _amount) external {
        address[] memory marketToEnter = new address[](1);
        marketToEnter[0] = _poolToken;
        comptroller.enterMarkets(marketToEnter);
        address underlying = IVToken(_poolToken).underlying();
        ERC20(underlying).safeApprove(_poolToken, type(uint256).max);
        require(IVToken(_poolToken).mint(_amount) == 0, "Mint fail");
    }

    function venusBorrow(address _poolToken, uint256 _amount) external {
        require(IVToken(_poolToken).borrow(_amount) == 0, "Borrow fail");
    }

    function venusWithdraw(address _poolToken, uint256 _amount) external {
        IVToken(_poolToken).redeemUnderlying(_amount);
    }

    function venusRepay(address _poolToken, uint256 _amount) external {
        address underlying = IVToken(_poolToken).underlying();
        ERC20(underlying).safeApprove(_poolToken, type(uint256).max);
        IVToken(_poolToken).repayBorrow(_amount);
    }

    function venusClaimRewards(address[] memory assets) external {
        comptroller.claimVenus(address(this), assets);
    }

    function balanceOf(address _token) external view returns (uint256) {
        return ERC20(_token).balanceOf(address(this));
    }

    function approve(address _token, uint256 _amount) external {
        ERC20(_token).safeApprove(address(evoq), _amount);
    }

    function approve(address _token, address _spender, uint256 _amount) external {
        ERC20(_token).safeApprove(_spender, _amount);
    }

    function createMarket(address _underlyingToken, Types.MarketParameters calldata _marketParams) external {
        evoq.createMarket(_underlyingToken, _marketParams);
    }

    function setReserveFactor(address _poolToken, uint16 _reserveFactor) external {
        evoq.setReserveFactor(_poolToken, _reserveFactor);
    }

    function supply(address _poolToken, uint256 _amount) external {
        evoq.supply(_poolToken, _amount);
    }

    function supply(address _poolToken, address _onBehalf, uint256 _amount) public {
        evoq.supply(_poolToken, _onBehalf, _amount);
    }

    function supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching) public {
        evoq.supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);
    }

    function supply(address _poolToken, uint256 _amount, uint256 _maxGasForMatching) external {
        supply(_poolToken, address(this), _amount, _maxGasForMatching);
    }

    function borrow(address _poolToken, uint256 _amount) external {
        evoq.borrow(_poolToken, _amount);
    }

    function borrow(address _poolToken, uint256 _amount, uint256 _maxGasForMatching) external {
        evoq.borrow(_poolToken, _amount, address(this), address(this), _maxGasForMatching);
    }

    function withdraw(address _poolToken, uint256 _amount) external {
        evoq.withdraw(_poolToken, _amount);
    }

    function withdraw(address _poolToken, uint256 _amount, address _receiver) external {
        evoq.withdraw(_poolToken, _amount, address(this), _receiver);
    }

    function repay(address _poolToken, uint256 _amount) external {
        evoq.repay(_poolToken, _amount);
    }

    function repay(address _poolToken, address _onBehalf, uint256 _amount) public {
        evoq.repay(_poolToken, _onBehalf, _amount);
    }

    function liquidate(address _poolTokenBorrowed, address _poolTokenCollateral, address _borrower, uint256 _amount)
        external
    {
        evoq.liquidate(_poolTokenBorrowed, _poolTokenCollateral, _borrower, _amount);
    }

    function setMaxSortedUsers(uint256 _newMaxSortedUsers) external {
        evoq.setMaxSortedUsers(_newMaxSortedUsers);
    }

    function setDefaultMaxGasForMatching(Types.MaxGasForMatching memory _maxGasForMatching) external {
        evoq.setDefaultMaxGasForMatching(_maxGasForMatching);
    }

    function claimRewards(address[] calldata _assets) external returns (uint256 claimedAmount) {
        return evoq.claimRewards(_assets);
    }

    function setIsP2PDisabled(address _market, bool _isPaused) external {
        evoq.setIsP2PDisabled(_market, _isPaused);
    }

    function setTreasuryVault(address _newTreasuryVault) external {
        evoq.setTreasuryVault(_newTreasuryVault);
    }

    function setIsSupplyPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsSupplyPaused(_poolToken, _isPaused);
    }

    function setIsBorrowPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsBorrowPaused(_poolToken, _isPaused);
    }

    function setIsWithdrawPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsWithdrawPaused(_poolToken, _isPaused);
    }

    function setIsRepayPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsRepayPaused(_poolToken, _isPaused);
    }

    function setIsLiquidateCollateralPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsLiquidateCollateralPaused(_poolToken, _isPaused);
    }

    function setIsLiquidateBorrowPaused(address _poolToken, bool _isPaused) external {
        evoq.setIsLiquidateBorrowPaused(_poolToken, _isPaused);
    }

    // extension
    function supplyBNB() external payable {
        wbnbGateway.supplyBNB{value: msg.value}(address(this));
    }
}
