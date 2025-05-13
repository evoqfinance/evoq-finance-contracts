// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IComptroller {
    enum Action {
        MINT,
        REDEEM,
        BORROW,
        REPAY,
        SEIZE,
        LIQUIDATE,
        TRANSFER,
        ENTER_MARKET,
        EXIT_MARKET
    }

    struct VenusMarketState {
        /// @notice The market's last updated venusBorrowIndex or venusSupplyIndex
        uint224 index;
        /// @notice The block number the index was last updated at
        uint32 block;
    }

    function supportMarket(address vToken) external returns (bool);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function closeFactorMantissa() external view returns (uint256);

    function admin() external view returns (address);

    function allMarkets(uint256) external view returns (IVToken);

    function oracle() external view returns (address);

    function borrowCaps(address) external view returns (uint256);

    function supplyCaps(address) external view returns (uint256);

    function markets(address) external view returns (bool isListed, uint256 collateralFactorMantissa, bool isVenus);

    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function exitMarket(address vToken) external returns (uint256);

    function mintAllowed(address vToken, address minter, uint256 mintAmount) external returns (uint256);

    function mintVerify(address vToken, address minter, uint256 mintAmount, uint256 mintTokens) external;

    function redeemAllowed(address vToken, address redeemer, uint256 redeemTokens) external returns (uint256);

    function redeemVerify(address vToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external;

    function borrowAllowed(address vToken, address borrower, uint256 borrowAmount) external returns (uint256);

    function borrowVerify(address vToken, address borrower, uint256 borrowAmount) external;

    function repayBorrowAllowed(address vToken, address payer, address borrower, uint256 repayAmount)
        external
        returns (uint256);

    function repayBorrowVerify(
        address vToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external;

    function liquidateBorrowAllowed(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function liquidateBorrowVerify(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external;

    function seizeAllowed(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function seizeVerify(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external;

    function transferAllowed(address vToken, address src, address dst, uint256 transferTokens)
        external
        returns (uint256);

    function transferVerify(address vToken, address src, address dst, uint256 transferTokens) external;

    /**
     * Liquidity/Liquidation Calculations **
     */
    function liquidateCalculateSeizeTokens(address vTokenBorrowed, address vTokenCollateral, uint256 repayAmount)
        external
        view
        returns (uint256, uint256);

    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);

    function getHypotheticalAccountLiquidity(address, address, uint256, uint256)
        external
        returns (uint256, uint256, uint256);

    function checkMembership(address, address) external view returns (bool);

    function mintGuardianPaused(address) external view returns (bool);

    function borrowGuardianPaused(address) external view returns (bool);

    function seizeGuardianPaused() external view returns (bool);

    function claimVenus(address holder) external;

    function claimVenus(address holder, address[] memory vTokens) external;

    function venusSpeeds(address) external view returns (uint256);

    function venusSupplySpeeds(address) external view returns (uint256);

    function venusBorrowSpeeds(address) external view returns (uint256);

    function venusSupplyState(address) external view returns (VenusMarketState memory);

    function venusBorrowState(address) external view returns (VenusMarketState memory);

    function getXVSAddress() external view returns (address);

    function _setPriceOracle(address newOracle) external returns (uint256);

    function _setActionsPaused(address[] calldata markets_, Action[] calldata actions_, bool paused_) external;

    function _setCollateralFactor(IVToken vToken, uint256 newCollateralFactorMantissa) external returns (uint256);

    function _setVenusSpeeds(IVToken[] memory vTokens, uint256[] memory supplySpeeds, uint256[] memory borrowSpeeds)
        external;

    function _setMarketBorrowCaps(IVToken[] calldata vTokens, uint256[] calldata newBorrowCaps) external;
}

interface IInterestRateModel {
    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorMantissa)
        external
        view
        returns (uint256);

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view returns (uint256);
}

interface IVToken {
    function isVToken() external returns (bool);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getCash() external view returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    function borrowRate() external returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrow(uint256) external returns (uint256);

    function repayBorrow(uint256) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function liquidateBorrow(address borrower, uint256 repayAmount, address vTokenCollateral)
        external
        returns (uint256);

    function underlying() external view returns (address);

    function mint(uint256) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function accrueInterest() external returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function interestRateModel() external view returns (IInterestRateModel);

    function reserveFactorMantissa() external view returns (uint256);

    /**
     * Admin Functions **
     */
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint256);

    function _acceptAdmin() external returns (uint256);

    function _setComptroller(IComptroller newComptroller) external returns (uint256);

    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function _setInterestRateModel(IInterestRateModel newInterestRateModel) external returns (uint256);
}

interface IVBnb is IVToken {
    function mint() external payable;

    function repayBorrow() external payable;
}

interface IVenusOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
}

interface ComptrollerTypes {
    enum Action {
        MINT,
        REDEEM,
        BORROW,
        REPAY,
        SEIZE,
        LIQUIDATE,
        TRANSFER,
        ENTER_MARKET,
        EXIT_MARKET
    }
}
