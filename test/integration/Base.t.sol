// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/RUSD.sol";
import "../../src/Oracle.sol";
import "../../src/Vault.sol";

/// @dev Shared setup for all integration tests.
///      Deploys RUSD, Oracle (at $5/PAS), and Vault, then wires them together.
abstract contract Base is Test {
    RUSD internal rusd;
    Oracle internal oracle;
    Vault internal vault;

    // Canonical price: 1 PAS = $5.00 (18-decimal fixed point)
    uint256 internal constant INITIAL_PRICE = 5e18;

    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");

    function setUp() public virtual {
        rusd   = new RUSD();
        oracle = new Oracle(INITIAL_PRICE);
        vault  = new Vault(address(rusd), address(oracle));
        rusd.setVault(address(vault));

        // Fund test accounts with PAS (native token)
        vm.deal(alice, 1000 ether);
        vm.deal(bob,   1000 ether);
    }

    // --- Helpers ---

    /// @dev Returns how much rUSD alice can mint given collateral and price,
    ///      targeting exactly MIN_RATIO (150%).
    ///      mintable = collateral * price / MIN_RATIO
    function _maxRUSD(uint256 collateral) internal view returns (uint256) {
        return collateral * oracle.getPrice() / 1e18 * 100 / vault.MIN_RATIO();
    }
}
