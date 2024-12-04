# Evoq

Evoq is a modular money market optimizer interacting with the existing lending protocols. As a pool optimizer, Evoq connects lenders with borrowers directly, improving capital efficiency and yields while maintaining liquidity and risk levels of the underlying protocol.

## Usage

```sh
git clone --recurse-submodules https://github.com/evoqfinance/evoq-finance-contracts
```

### Setup

```sh
cp .env.example .env.local
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
| Evoq | Business | [Evoq.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Evoq.sol) | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) | Main contract for Evoq protocol |
| EvoqGovernance | Abstract | [EvoqGovernance.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqGovernance.sol) | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) | Governance functionalities |
| EvoqStorage | Abstract | [EvoqStorage.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqStorage.sol) | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) | Storage for Evoq protocol |
| EvoqUtils | Abstract | [EvoqUtils.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/EvoqUtils.sol) | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) | Utility functions for Evoq |
| MatchingEngine | Abstract | [MatchingEngine.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/MatchingEngine.sol) | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) | Matches lenders with borrowers |
| PositionsManager | Business | [PositionsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/PositionsManager.sol) | [PositionsManager](https://bscscan.com/address/0x3f150EeD3a515587db03C667abD9A22E46EE7aBA) | Manages lending and borrowing positions |
| InterestRatesManager | Business | [InterestRatesManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/InterestRatesManager.sol) | [InterestRatesManager](https://bscscan.com/address/0x520f3Bf2b17EF520702cAb7c2b16caFfF7544D68) | Manages interest rates |
| InterestRatesModel | Library | [InterestRatesModel.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/libraries/InterestRatesModel.sol) | [InterestRatesManager](https://bscscan.com/address/0x520f3Bf2b17EF520702cAb7c2b16caFfF7544D68) | Library for interest rate calculations |
| RewardsManager | Business | [RewardsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/RewardsManager.sol) | [RewardsManager](https://bscscan.com/address/0x57812cB161446D39b95d096Da437D58204f12ce0) | Manages rewards distribution |
| Treasury | Business | [Treasury.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Treasury.sol) | [Treasury](https://bscscan.com/address/0x9CFe75c7871cFB921Fd53e62e3CD4f8d09eeAbA7) | Manages protocol funds |
| WBNBGateway | Business | [WBNBGateway.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/extensions/WBNBGateway.sol) | [WBNBGateway](https://bscscan.com/address/0xA344db2c03491E902A3Cd38c8386e40687cCf724) | Converting between BNB and WBNB |
| Lens | Utility | [Lens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/Lens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides protocol data |
| LensExtension | Utility | [LensExtension.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/LensExtension.sol) | [LensExtension](https://bscscan.com/address/0x2B9027632D322B35eF3AE6D7288B9163a7E86f30) | Extends Lens functionalities |
| LensStorage | Abstract | [LensStorage.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/LensStorage.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Storage for Lens data |
| MarketLens | Abstract | [MarketLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/MarketLens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides market data |
| IndexesLens | Abstract | [IndexesLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/IndexesLens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides indexes value |
| RateLens | Abstract | [RateLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/RateLens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides rate data |
| RewardLens | Abstract | [RewardLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/RewardLens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides reward data |
| UsersLens | Abstract | [UsersLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/UsersLens.sol) | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127) | Provides user data |
| DataLens | Utility | [DataLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/DataLens.sol) | [DataLens](https://bscscan.com/address/0xda859d83b66982565ff17030d0697eca9f881b5c) | Provides aggregated data |

## Links

- [Evoq Home](https://evoq.finance)
- [X (Twitter)](https://x.com/Evoq_Finance)
