#!/usr/bin/env bash
set -euo pipefail

RPC="${RPC_URL:-https://eth-rpc-testnet.polkadot.io/}"
RUSD="0xe321098307B309bAab006e8600439a1c948f0860"
ORACLE="0x5A2B2C4750c1034d39f30441642C8Be220F52618"
VAULT="0xA3cc725D53D69Aa5e570D73390c152f76F7BC0CE"

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Error: PRIVATE_KEY not set" >&2
  exit 1
fi

ME=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "Deployer: $ME"

# --- Static checks ---
echo "Oracle price:  $(cast call $ORACLE 'getPrice()(uint256)' --rpc-url $RPC)"
echo "RUSD supply:   $(cast call $RUSD   'totalSupply()(uint256)' --rpc-url $RPC)"
echo "Vault wired:   $(cast call $RUSD   'vault()(address)' --rpc-url $RPC)"
echo "Static checks passed"

# --- Lifecycle: open → mint → burn → close ---
cast send $VAULT "open()" --value 1ether --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Vault opened with 1 PAS"

MINTABLE=$(cast call $VAULT "maxMintable(address)(uint256)" "$ME" --rpc-url $RPC | awk '{print $1}')
cast send $VAULT "mint(uint256)" "$MINTABLE" --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Minted: $MINTABLE rUSD"

DEBT=$(cast call $VAULT "debtWithFee(address)(uint256)" "$ME" --rpc-url $RPC | awk '{print $1}')
cast send $VAULT "burn(uint256)" "$DEBT" --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Burned: $DEBT rUSD"

cast send $VAULT "close()" --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Position closed"

echo "Smoke test passed"
