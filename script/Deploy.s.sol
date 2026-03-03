// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/RUSD.sol";
import "../src/Oracle.sol";
import "../src/Vault.sol";

/// @notice Deploys the full ReviveUSD protocol in the correct order and wires contracts.
///
/// Usage:
///   forge script script/Deploy.s.sol \
///       --resolc \
///       --rpc-url https://testnet-passet-hub-eth-rpc.polkadot.io \
///       --private-key $PRIVATE_KEY \
///       --broadcast
///
/// After deployment, verify on Blockscout:
///   forge verify-contract $RUSD_ADDR  src/RUSD.sol:RUSD   --chain polkadot-testnet
///   forge verify-contract $ORACLE_ADDR src/Oracle.sol:Oracle --chain polkadot-testnet
///   forge verify-contract $VAULT_ADDR  src/Vault.sol:Vault  --chain polkadot-testnet
contract Deploy is Script {
    // Initial PAS/USD price: $5.00 (18-decimal fixed point)
    // Adjust before deployment to match the current market price.
    uint256 constant INITIAL_PRICE = 5e18;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy the stablecoin token (no vault set yet)
        RUSD rusd = new RUSD();
        console.log("RUSD deployed at:  ", address(rusd));

        // 2. Deploy the price oracle with the initial PAS/USD price
        Oracle oracle = new Oracle(INITIAL_PRICE);
        console.log("Oracle deployed at:", address(oracle));

        // 3. Deploy the vault, wiring in both dependencies
        Vault vault = new Vault(address(rusd), address(oracle));
        console.log("Vault deployed at: ", address(vault));

        // 4. Authorise the vault to mint and burn rUSD
        rusd.setVault(address(vault));
        console.log("Vault authorised to mint/burn rUSD");

        vm.stopBroadcast();

        // Print a summary for easy copy-paste into .env / frontend config
        console.log("\n--- Deployment summary ---");
        console.log("RUSD   =", address(rusd));
        console.log("ORACLE =", address(oracle));
        console.log("VAULT  =", address(vault));
    }
}
