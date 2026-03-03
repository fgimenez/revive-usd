// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/RUSD.sol";
import "../src/Oracle.sol";
import "../src/Vault.sol";

/// @notice Smoke test against live Passet Hub deployment.
///         Verifies contract wiring and exercises the full CDP lifecycle:
///         open → mint → burn → close.
///
/// Usage:
///   forge script script/SmokeTest.s.sol \
///       --resolc \
///       --rpc-url https://eth-rpc-testnet.polkadot.io/ \
///       --private-key $DEPLOYER_PK \
///       --broadcast
contract SmokeTest is Script {
    address constant RUSD_ADDR   = 0xe321098307B309bAab006e8600439a1c948f0860;
    address constant ORACLE_ADDR = 0x5A2B2C4750c1034d39f30441642C8Be220F52618;
    address constant VAULT_ADDR  = 0xA3cc725D53D69Aa5e570D73390c152f76F7BC0CE;

    function run() external {
        RUSD   rusd   = RUSD(RUSD_ADDR);
        Oracle oracle = Oracle(ORACLE_ADDR);
        Vault  vault  = Vault(VAULT_ADDR);

        // --- Static checks (no broadcast needed) ---
        require(rusd.vault() == VAULT_ADDR,   "RUSD vault not wired");
        require(oracle.getPrice() > 0,        "Oracle price is zero");
        require(vault.MIN_RATIO() == 150,     "MIN_RATIO mismatch");
        require(vault.LIQ_THRESHOLD() == 130, "LIQ_THRESHOLD mismatch");
        console.log("Static checks passed");
        console.log("  Oracle price (USD, 18 dec):", oracle.getPrice());
        console.log("  rUSD total supply:          ", rusd.totalSupply());

        // --- Transaction smoke test ---
        vm.startBroadcast();

        address me = vm.addr(vm.envUint("PRIVATE_KEY"));
        console.log("Broadcaster:", me);

        // Open a small position: 1 PAS collateral
        uint256 collateral = 1 ether;
        vault.open{value: collateral}();
        console.log("Vault opened with 1 PAS collateral");

        // Mint up to max mintable rUSD
        uint256 mintable = vault.maxMintable(me);
        require(mintable > 0, "Nothing mintable");
        vault.mint(mintable);
        console.log("Minted rUSD:", mintable);

        // Burn all debt
        uint256 debt = vault.debtWithFee(me);
        vault.burn(debt);
        console.log("Burned rUSD debt:", debt);

        // Close position
        vault.close();
        console.log("Position closed");

        vm.stopBroadcast();

        console.log("Smoke test passed");
    }
}
