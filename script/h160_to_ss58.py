#!/usr/bin/env python3
"""
Convert an Ethereum H160 address to its Substrate SS58 equivalent for Polkadot Hub.

On Polkadot Hub (pallet-revive), H160 Ethereum addresses map to Substrate AccountId32
by prepending 12 bytes of 0xEE.  The resulting 32-byte account can be SS58-encoded for
use in Polkadot wallets and the faucet.

Usage:
    python3 script/h160_to_ss58.py 0xB8E33ae09B968540cCD9b91a491Ed1cA89F7C64D
    python3 script/h160_to_ss58.py B8E33ae09B968540cCD9b91a491Ed1cA89F7C64D

Network prefixes:
    0   = Polkadot / Paseo / Passet Hub testnet  ← default
    42  = generic Substrate
"""

import hashlib
import sys

# Base58 alphabet used by Substrate (Bitcoin alphabet)
_ALPHABET = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def _b58encode(data: bytes) -> str:
    n = int.from_bytes(data, "big")
    result = []
    while n:
        n, rem = divmod(n, 58)
        result.append(_ALPHABET[rem])
    # Leading zero bytes → leading '1's
    for byte in data:
        if byte == 0:
            result.append(_ALPHABET[0])
        else:
            break
    return bytes(reversed(result)).decode()


def ss58_encode(account_id: bytes, prefix: int = 42) -> str:
    """Encode a 32-byte AccountId to SS58 with the given network prefix."""
    if len(account_id) != 32:
        raise ValueError(f"AccountId must be 32 bytes, got {len(account_id)}")
    if prefix < 64:
        prefix_bytes = bytes([prefix])
    else:
        p = ((prefix & 0xFC) >> 2) | 0x40
        q = (prefix >> 8) | ((prefix & 0x03) << 6)
        prefix_bytes = bytes([p, q])
    payload = prefix_bytes + account_id
    checksum = hashlib.blake2b(b"SS58PRE" + payload, digest_size=64).digest()[:2]
    return _b58encode(payload + checksum)


def h160_to_account_id32(h160: str) -> bytes:
    """Pad an H160 address to 32 bytes with 12 trailing 0xEE bytes (pallet-revive convention).

    pallet-revive appends 0xEE bytes AFTER the 20-byte H160:
        AccountId32 = H160 (20 bytes) || [0xEE] * 12
    """
    h160 = h160.removeprefix("0x").removeprefix("0X")
    if len(h160) != 40:
        raise ValueError(f"Expected 40 hex chars, got {len(h160)}")
    return bytes.fromhex(h160) + bytes([0xEE] * 12)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    h160 = sys.argv[1]
    account_id32 = h160_to_account_id32(h160)

    ss58_0  = ss58_encode(account_id32, prefix=0)    # Polkadot / Paseo / Passet Hub
    ss58_42 = ss58_encode(account_id32, prefix=42)   # generic Substrate

    print(f"H160         : 0x{h160.removeprefix('0x').removeprefix('0X')}")
    print(f"AccountId32  : 0x{account_id32.hex()}")
    print(f"SS58 (0)     : {ss58_0}   ← use this for Paseo/Passet Hub faucet")
    print(f"SS58 (42)    : {ss58_42}")


if __name__ == "__main__":
    main()
