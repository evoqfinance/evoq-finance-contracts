RPC_URL=http://localhost:8545
COMPTROLLER=0xfD36E2c2a6789Db23113685031d7F16329158384
COMPTROLLER_ADMIN=0x939bD8d64c0A9583A7Dcea9933f7b21697ab6396 # timelock

# IMPORTANT: look at this if there is `error code 3: execution reverted, data: "0x"`
CUSTOM_ORACLE=0xdBD296711eC8eF9Aacb623ee3F1C0922dce0D7b2

cast rpc anvil_impersonateAccount $COMPTROLLER_ADMIN --rpc-url $RPC_URL
cast send $COMPTROLLER --from $COMPTROLLER_ADMIN "_setPriceOracle(address)" $CUSTOM_ORACLE --unlocked --rpc-url $RPC_URL