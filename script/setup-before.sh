RPC_URL=http://localhost:8545
USDC=0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d
WHALE=0x554b52bf57b387fd09d6644368c5a8aacaaf5ae0
ME=0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
ME2=0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f
ME_PRIV_KEY=0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c

cast rpc anvil_impersonateAccount $WHALE --rpc-url $RPC_URL

# send 300k USDC to me + me2
cast send $USDC --from $WHALE "transfer(address,uint256)(bool)" $ME 300000000000000000000000 --unlocked --rpc-url $RPC_URL
cast send $USDC --from $WHALE "transfer(address,uint256)(bool)" $ME2 300000000000000000000000 --unlocked --rpc-url $RPC_URL
cast send $WBNB --from $ME2 "deposit()" --value 1000000000000000000000 --private-key $ME_PRIV_KEY --rpc-url $RPC_URL
