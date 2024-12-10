-include .env.local
.EXPORT_ALL_VARIABLES:

# initialize the project
install:
	foundryup
	git submodule update --init --recursive
	chmod +x script/*.sh

# start local mainnet fork
anvil:
	anvil --chain-id 1337 --fork-url ${RPC_URL} --fork-block-number "${FORK_BLOCK_NUMBER}"

# start local testnet fork on VPS
anvil-remote:
	anvil --chain-id 123 --fork-url ${RPC_URL} --fork-block-number "${FORK_BLOCK_NUMBER}"

# run all tests
test:
	forge test --fork-url ${RPC_URL} --fork-block-number ${FORK_BLOCK_NUMBER} -vvv | tee trace.txt

# run a specific test
test-%:
	@FOUNDRY_MATCH_TEST=$* make test

# deploy contracts to local fork and run setup scripts for easy testing
deploy-local:
	./script/setup-before.sh && \
	forge script script/DeployLocal.s.sol:Deploy --rpc-url 127.0.0.1:8545 --private-key ${PRIV_KEY} --broadcast -vvv && \
	./script/setup-after.sh

# deploy contracts to testnet
deploy-testnet:
	forge script script/DeployTestnet.s.sol:Deploy --rpc-url ${TESTNET_RPC_URL} --private-key ${TESTNET_PRIV_KEY} --broadcast --force -vvv

# deploy contracts to mainnet
deploy-mainnet:
	forge script script/DeployMainnet.s.sol:Deploy --rpc-url ${MAINNET_RPC_URL} --private-key ${MAINNET_PRIV_KEY} --broadcast --force -vvv

# faucet for testing things out
faucet:
	./script/faucet.sh ${WALLET}

# get addresses from the deployed contracts
list-deployed-addresses:
	forge script script/helpers/ListDeployedAddresses.s.sol -vvv

# verify contracts on bscscan
verify:
	./script/verify.sh

storage-layout-generate:
	@./script/storage-layout.sh generate snapshot/.storage-layout Evoq

storage-layout-check:
	@./script/storage-layout.sh check snapshot/.storage-layout Evoq

gas-report:
	forge test --gas-report --fork-url ${RPC_URL} --fork-block-number ${FORK_BLOCK_NUMBER} -vvv | tee trace.ansi

.PHONY: test