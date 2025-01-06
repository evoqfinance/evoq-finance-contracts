# Evoq

Evoq is a modular money market optimizer interacting with the existing lending protocols. As a pool optimizer, Evoq connects lenders with borrowers directly, improving capital efficiency and yields while maintaining liquidity and risk levels of the underlying protocol.

## Usage

```sh
git clone --recurse-submodules https://github.com/evoqfinance/evoq-finance-contracts
```

### Setup

```sh
cp .env.example .env
make install
```

### Deploy local mainnet fork

```sh
make anvil
make deploy-local
```

### Deploy testnet

```sh
make deploy-testnet
```

### Deploy mainnet

```sh
make deploy-mainnet
```

See more: `makefile`

## Docs

[Evoq Finance Docs](https://docs.evoq.finance/)

## Contract Deployments

List of deployed contracts that will be audited.
| Contract Name | Type | Code | Contract Address | Description |
| -------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| Evoq | Business | [Evoq.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Evoq.sol) | [Proxy](https://bscscan.com/address/0xF9C74A65B04C73B911879DB0131616C556A626bE) / [Implementation](https://bscscan.com/address/0x93777a62cbd899f9f8630686C4e7000C6E074185) | Main contract for Evoq protocol |
| EvoqGovernance | Abstract | [EvoqGovernance.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqGovernance.sol) | [Proxy](https://bscscan.com/address/0xF9C74A65B04C73B911879DB0131616C556A626bE) / [Implementation](https://bscscan.com/address/0x93777a62cbd899f9f8630686C4e7000C6E074185) | Governance functionalities |
| EvoqStorage | Abstract | [EvoqStorage.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqStorage.sol) | [Proxy](https://bscscan.com/address/0xF9C74A65B04C73B911879DB0131616C556A626bE) / [Implementation](https://bscscan.com/address/0x93777a62cbd899f9f8630686C4e7000C6E074185) | Storage for Evoq protocol |
| EvoqUtils | Abstract | [EvoqUtils.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqUtils.sol) | [Proxy](https://bscscan.com/address/0xF9C74A65B04C73B911879DB0131616C556A626bE) / [Implementation](https://bscscan.com/address/0x93777a62cbd899f9f8630686C4e7000C6E074185) | Utility functions for Evoq |
| MatchingEngine | Abstract | [MatchingEngine.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/MatchingEngine.sol) | [Proxy](https://bscscan.com/address/0xF9C74A65B04C73B911879DB0131616C556A626bE) / [Implementation](https://bscscan.com/address/0x93777a62cbd899f9f8630686C4e7000C6E074185) | Matches lenders with borrowers |
| PositionsManager | Business | [PositionsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/PositionsManager.sol) | [PositionsManager](https://bscscan.com/address/0x2e595938c0c797e5d404CD4d0063dAE2716D8E02) | Manages lending and borrowing positions |
| InterestRatesManager | Business | [InterestRatesManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/InterestRatesManager.sol) | [InterestRatesManager](https://bscscan.com/address/0x20C238e1A2829Fc8c14bbDE4A71a401903d60C37) | Manages interest rates |
| InterestRatesModel | Library | [InterestRatesModel.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/libraries/InterestRatesModel.sol) | [InterestRatesManager](https://bscscan.com/address/0x20C238e1A2829Fc8c14bbDE4A71a401903d60C37) | Library for interest rate calculations |
| RewardsManager | Business | [RewardsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/RewardsManager.sol) | [Proxy](https://bscscan.com/address/0xEf48E83e6f6C7b26feaBF733Ddc6399092c7142e) / [Implementation](https://bscscan.com/address/0x84D33eCF36653DF57f0F9B136Dbdc07F3739D814) | Manages rewards distribution |
| Treasury | Business | [Treasury.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Treasury.sol) | [Treasury](https://bscscan.com/address/0x4697C0d5A761b3B30d9248419ece5fA80574D2aa) | Manages protocol funds |
| WBNBGateway | Business | [WBNBGateway.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/extensions/WBNBGateway.sol) | [WBNBGateway](https://bscscan.com/address/0xe684F77198Eb31a11A6B3Effb8995A2e079e150C) | Converting between BNB and WBNB |
| Lens | Utility | [Lens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/Lens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides protocol data |
| LensExtension | Utility | [LensExtension.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/LensExtension.sol) | [LensExtension](https://bscscan.com/address/0x1ed7fA82379bA66Ce972E75162E36ae78dEF541A) | Extends Lens functionalities |
| LensStorage | Abstract | [LensStorage.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/LensStorage.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Storage for Lens data |
| MarketLens | Abstract | [MarketLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/MarketLens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides market data |
| IndexesLens | Abstract | [IndexesLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/IndexesLens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides indexes value |
| RateLens | Abstract | [RateLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/RateLens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides rate data |
| RewardLens | Abstract | [RewardLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/RewardLens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides reward data |
| UsersLens | Abstract | [UsersLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/UsersLens.sol) | [Lens](https://bscscan.com/address/0x5576207849D570bfE1acB6004595561851813198) | Provides user data |
| DataLens | Utility | [DataLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/DataLens.sol) | [DataLens](https://bscscan.com/address/0x1726D0473bFD05872d9538896901A4b00B9f4073) | Provides aggregated data |

## Links

- [Evoq Home](https://evoq.finance)
- [X (Twitter)](https://x.com/Evoq_Finance)
