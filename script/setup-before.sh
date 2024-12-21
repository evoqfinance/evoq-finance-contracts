RPC_URL=http://localhost:8545
USDC=0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d
WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
BTCB=0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c

WHALE_1=0x554b52bf57b387fd09d6644368c5a8aacaaf5ae0 # BNB and USDC
WHALE_2=0xD3a22590f8243f8E83Ac230D1842C9Af0404C4A1 # BTCB

ACCOUNT_8=0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f
ACCOUNT_8_PRIV=0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
ACCOUNT_9=0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
ACCOUNT_9_PRIV=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

cast rpc anvil_impersonateAccount $WHALE_1 --rpc-url $RPC_URL

# send 300k USDC to ACCOUNT_8 and ACCOUNT_9
cast send $USDC --from $WHALE_1 "transfer(address,uint256)(bool)" $ACCOUNT_8 300000000000000000000000 --unlocked --rpc-url $RPC_URL # 300k USDC
cast send $USDC --from $WHALE_1 "transfer(address,uint256)(bool)" $ACCOUNT_9 300000000000000000000000 --unlocked --rpc-url $RPC_URL

cast send $WBNB --from $ACCOUNT_8 "deposit()" --value 1000000000000000000000 --private-key $ACCOUNT_8_PRIV --rpc-url $RPC_URL # 1000 BNB
cast send $WBNB --from $ACCOUNT_9 "deposit()" --value 1000000000000000000000 --private-key $ACCOUNT_9_PRIV --rpc-url $RPC_URL

cast rpc anvil_impersonateAccount $WHALE_2 --rpc-url $RPC_URL

cast send $BTCB --from $WHALE_2 "transfer(address,uint256)(bool)" $ACCOUNT_9 100000000000000000000 --unlocked --rpc-url $RPC_URL # 100 BTCB
