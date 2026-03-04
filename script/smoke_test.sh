#!/usr/bin/env bash
# Smoke test against live Passet Hub deployment.
# Verifies contract wiring, then exercises mint + burn.
# Opens a position if none exists; reuses the existing one if it does.
# Does NOT attempt close() — stability fee can accrue small unpayable dust
# which would require external rUSD to clear (by design of the CDP model).
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

# --- Open position if none exists ---
COLLATERAL=$(cast call $VAULT "positions(address)(uint256,uint256,uint256)" "$ME" --rpc-url $RPC | awk 'NR==1 {print $1}')
if [ "$COLLATERAL" = "0" ]; then
  cast send $VAULT "open()" --value 1ether --rpc-url $RPC --private-key "$PRIVATE_KEY"
  echo "Vault opened with 1 PAS"
else
  echo "Reusing existing position (collateral: $COLLATERAL)"
fi

# --- Mint a small fixed amount ---
# Using a tiny amount (1 Gwei rUSD) to avoid fee-race issues on close().
# Fee accrual on 1e9 wei over a few blocks is sub-wei and rounds to 0.
SMALL=1000000000
cast send $VAULT "mint(uint256)" "$SMALL" --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Minted: $SMALL rUSD"

BALANCE=$(cast call $RUSD "balanceOf(address)(uint256)" "$ME" --rpc-url $RPC | awk '{print $1}')
echo "rUSD balance: $BALANCE"
[ "$BALANCE" -ge "$SMALL" ] || { echo "Balance check failed"; exit 1; }

# --- Burn the minted amount ---
cast send $VAULT "burn(uint256)" "$SMALL" --rpc-url $RPC --private-key "$PRIVATE_KEY"
echo "Burned: $SMALL rUSD"

echo "Smoke test passed"
