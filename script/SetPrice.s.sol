// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Oracle.sol";

/// @notice Admin script: update the PAS/USD price on the deployed Oracle.
///
/// Usage:
///   forge script script/SetPrice.s.sol \
///       --resolc \
///       --rpc-url https://testnet-passet-hub-eth-rpc.polkadot.io \
///       --private-key $PRIVATE_KEY \
///       --broadcast \
///       --sig "run(address,uint256)" $ORACLE_ADDR 3200000000000000000
///
/// Price is in 18-decimal fixed point: 1e18 = $1.00
///   $5.00  → 5000000000000000000  (5e18)
///   $3.20  → 3200000000000000000  (3.2e18)
///   $1.50  → 1500000000000000000  (1.5e18)
contract SetPrice is Script {
    function run(address oracleAddr, uint256 newPrice) external {
        vm.startBroadcast();

        Oracle oracle = Oracle(oracleAddr);
        uint256 oldPrice = oracle.getPrice();

        oracle.setPrice(newPrice);

        console.log("Oracle:   ", oracleAddr);
        console.log("Old price:", oldPrice);
        console.log("New price:", newPrice);

        vm.stopBroadcast();
    }
}
