#!/bin/bash

# Load the .env file
if [ -f .env ]; then
  source .env
else
  echo ".env file not found!"
  exit 1
fi

EvoqWallet=0xF08d1c9eEB48aC664890ab4516B436D0606a6a25

InterestRatesManager=0x20C238e1A2829Fc8c14bbDE4A71a401903d60C37
PositionsManager=0x2e595938c0c797e5d404CD4d0063dAE2716D8E02
Evoq=0x93777a62cbd899f9f8630686C4e7000C6E074185
EvoqProxy=0xF9C74A65B04C73B911879DB0131616C556A626bE
RewardsManager=0x84D33eCF36653DF57f0F9B136Dbdc07F3739D814
RewardsManagerProxy=0xEf48E83e6f6C7b26feaBF733Ddc6399092c7142e
LensExtension=0x1ed7fA82379bA66Ce972E75162E36ae78dEF541A
Lens=0x5576207849D570bfE1acB6004595561851813198
DataLens=0x1726D0473bFD05872d9538896901A4b00B9f4073
Treasury=0x4697C0d5A761b3B30d9248419ece5fA80574D2aa
WBNBGateway=0xe684F77198Eb31a11A6B3Effb8995A2e079e150C

wBnb=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
vBnb=0xA07c5b74C9B40447a954e1466938b865b6BBea36


forge verify-contract --chain bsc --watch $InterestRatesManager InterestRatesManager

forge verify-contract --chain bsc --watch $PositionsManager PositionsManager

forge verify-contract --chain bsc --watch $Evoq Evoq
forge verify-contract --chain bsc --watch $EvoqProxy lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy \
      --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "$Evoq" "$EvoqWallet" "0x")

forge verify-contract --chain bsc --watch $RewardsManager RewardsManager
forge verify-contract --chain bsc --watch $RewardsManagerProxy lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy \
      --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "$RewardsManager" "$EvoqWallet" "0x")
    
forge verify-contract --chain bsc --watch $LensExtension LensExtension \
    --constructor-args $(cast abi-encode "constructor(address)" "$EvoqProxy")

forge verify-contract --chain bsc --watch $Lens Lens \
    --constructor-args $(cast abi-encode "constructor(address)" "$LensExtension")

forge verify-contract --chain bsc --watch $DataLens DataLens \
    --constructor-args $(cast abi-encode "constructor(address)" "$Lens")

forge verify-contract --chain bsc --watch $Treasury Treasury

forge verify-contract --chain bsc --watch $WBNBGateway WBNBGateway \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" "$EvoqProxy" "$wBnb" "$vBnb" "$Treasury")


# EXAMPLE:
# forge verify-contract \
#     --chain-id 11155111 \
#     --num-of-optimizations 1000000 \
#     --watch \
#     --constructor-args $(cast abi-encode "constructor(string,string,uint256,uint256)" "ForgeUSD" "FUSD" 18 1000000000000000000000) \
#     --etherscan-api-key <your_etherscan_api_key> \
#     --compiler-version v0.8.10+commit.fc410830 \
#     <the_contract_address> \
#     src/MyToken.sol:MyToken 