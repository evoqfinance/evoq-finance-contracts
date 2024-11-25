# Evoq

Evoq is a peer-to-peer lending protocol built on top of lending protocol like Venus. As a pool optimizer, Evoq connects lenders with borrowers directly, improving capital efficiency and yields while maintaining liquidity and risk levels of the underlying protocol.

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

| No. | Contract Name        | Type     | Github Link                                                                                                              | Contract Address                                                                                                                                                           |
| --- | -------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Evoq                 | Business | [Evoq.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Evoq.sol)                                 | [Proxy](https://bscscan.com/address/0x86BFB23777b1caD8438709970F8f54b136b49530) / [Implementation](https://bscscan.com/address/0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758) |
| 2   | PositionsManager     | Business | [PositionsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/PositionsManager.sol)         | [PositionsManager](https://bscscan.com/address/0x3f150EeD3a515587db03C667abD9A22E46EE7aBA)                                                                                 |
| 3   | InterestRatesManager | Business | [InterestRatesManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/InterestRatesManager.sol) | [InterestRatesManager](https://bscscan.com/address/0x520f3Bf2b17EF520702cAb7c2b16caFfF7544D68)                                                                             |
| 4   | RewardsManager       | Business | [RewardsManager.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/RewardsManager.sol)             | [RewardsManager](https://bscscan.com/address/0x57812cB161446D39b95d096Da437D58204f12ce0)                                                                                   |
| 5   | Treasury             | Business | [Treasury.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/Treasury.sol)                         | [Treasury](https://bscscan.com/address/0x9CFe75c7871cFB921Fd53e62e3CD4f8d09eeAbA7)                                                                                         |
| 6   | WBNBGateway          | Business | [WBNBGateway.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/extensions/WBNBGateway.sol)        | [WBNBGateway](https://bscscan.com/address/0xA344db2c03491E902A3Cd38c8386e40687cCf724)                                                                                      |
| 7   | Lens                 | Utility  | [Lens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/Lens.sol)                            | [Lens](https://bscscan.com/address/0xe0416C0E56D680e781cf87f6c9a959C7F07E0127)                                                                                             |
| 8   | LensExtension        | Utility  | [LensExtension.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/LensExtension.sol)          | [LensExtension](https://bscscan.com/address/0x2B9027632D322B35eF3AE6D7288B9163a7E86f30)                                                                                    |
| 9   | DataLens             | Utility  | [DataLens.sol](https://github.com/evoqfinance/evoq-finance-contracts/blob/main/src/lens/DataLens.sol)                    | [DataLens](https://bscscan.com/address/0xda859d83b66982565ff17030d0697eca9f881b5c)                                                                                         |

## Links

- [Evoq Home](https://evoq.finance)
- [X (Twitter)](https://x.com/Evoq_Finance)
