RPC_URL=http://localhost:8545

USDC=0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d
WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c

USDC_WHALE=0x554b52bf57b387fd09d6644368c5a8aacaaf5ae0
BNB_WHALE=0xF977814e90dA44bFA03b6295A0616a897441aceC
ME2=0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f

TARGET_WALLET=$1
USDC_SEND_AMOUNT=10000"000000000000000000" # use string to avoid overflow
BNB_SEND_AMOUNT=10"000000000000000000"
WBNB_SEND_AMOUNT=100"000000000000000000"

# send USDC
cast rpc anvil_impersonateAccount $USDC_WHALE --rpc-url $RPC_URL
cast send $USDC --from $USDC_WHALE "transfer(address,uint256)(bool)" $TARGET_WALLET $USDC_SEND_AMOUNT --unlocked --rpc-url $RPC_URL

# # send BNB
cast rpc anvil_impersonateAccount $BNB_WHALE --rpc-url $RPC_URL
cast send $TARGET_WALLET --from $BNB_WHALE --value $BNB_SEND_AMOUNT --unlocked --rpc-url $RPC_URL

# # send WBNB
cast send $WBNB --from $ME2 "deposit()" --value $WBNB_SEND_AMOUNT --private-key 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97 --rpc-url $RPC_URL
cast send $WBNB --from $ME2 "transfer(address,uint256)(bool)" $TARGET_WALLET $WBNB_SEND_AMOUNT --unlocked --rpc-url $RPC_URL
