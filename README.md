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
