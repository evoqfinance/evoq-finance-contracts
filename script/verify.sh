# forge verify-contract --chain bsc --watch 0xA344db2c03491E902A3Cd38c8386e40687cCf724 WBNBGateway \
#     --constructor-args $(cast abi-encode "constructor(address,address)" "0x86BFB23777b1caD8438709970F8f54b136b49530" "0xA07c5b74C9B40447a954e1466938b865b6BBea36")

# forge verify-contract --chain bsc --watch 0xAd69B8c66CA67f35AAfFbC9D68e2f370FA936758 Evoq

# forge verify-contract --chain bsc --watch 0x3f150EeD3a515587db03C667abD9A22E46EE7aBA PositionsManager

# forge verify-contract --chain bsc --watch 0xda859d83b66982565ff17030d0697eca9f881b5c DataLens \
#     --constructor-args $(cast abi-encode "constructor(address)" "0xe0416C0E56D680e781cf87f6c9a959C7F07E0127")


# Verify TransparentUpgradeableProxy
# forge verify-contract --chain bsc --watch 0x86BFB23777b1caD8438709970F8f54b136b49530 \
#       lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "0x11fb2A6115e372234ADC51e4a0a134fD5a4B59B9" "0xF08d1c9eEB48aC664890ab4516B436D0606a6a25" "0x")

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