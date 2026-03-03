// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/RUSD.sol";

contract RUSDTest is Test {
    RUSD internal rusd;

    address internal owner    = address(this);
    address internal vault    = makeAddr("vault");
    address internal attacker = makeAddr("attacker");
    address internal alice    = makeAddr("alice");

    function setUp() public {
        rusd = new RUSD();
        rusd.setVault(vault);
    }

    // --- Metadata ---

    function test_name() public view {
        assertEq(rusd.name(), "ReviveUSD");
    }

    function test_symbol() public view {
        assertEq(rusd.symbol(), "rUSD");
    }

    function test_decimals() public view {
        assertEq(rusd.decimals(), 18);
    }

    // --- setVault ---

    function test_setVaultOnlyOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        rusd.setVault(attacker);
    }

    function test_setVaultUpdatesVault() public {
        address newVault = makeAddr("newVault");
        rusd.setVault(newVault);
        assertEq(rusd.vault(), newVault);
    }

    // --- mint ---

    function test_mintOnlyVault() public {
        vm.prank(attacker);
        vm.expectRevert("RUSD: not vault");
        rusd.mint(alice, 100e18);
    }

    function test_mintIncreasesBalance() public {
        vm.prank(vault);
        rusd.mint(alice, 100e18);
        assertEq(rusd.balanceOf(alice), 100e18);
    }

    function test_mintIncreasesTotalSupply() public {
        vm.prank(vault);
        rusd.mint(alice, 100e18);
        assertEq(rusd.totalSupply(), 100e18);
    }

    function test_mintMultipleRecipients() public {
        address bob = makeAddr("bob");
        vm.startPrank(vault);
        rusd.mint(alice, 50e18);
        rusd.mint(bob,   75e18);
        vm.stopPrank();

        assertEq(rusd.totalSupply(), 125e18);
        assertEq(rusd.balanceOf(alice), 50e18);
        assertEq(rusd.balanceOf(bob),   75e18);
    }

    // --- burn ---

    function test_burnOnlyVault() public {
        vm.prank(vault);
        rusd.mint(alice, 100e18);

        vm.prank(attacker);
        vm.expectRevert("RUSD: not vault");
        rusd.burn(alice, 100e18);
    }

    function test_burnDecreasesBalance() public {
        vm.prank(vault);
        rusd.mint(alice, 100e18);

        vm.prank(vault);
        rusd.burn(alice, 40e18);

        assertEq(rusd.balanceOf(alice), 60e18);
    }

    function test_burnDecreasesTotalSupply() public {
        vm.prank(vault);
        rusd.mint(alice, 100e18);

        vm.prank(vault);
        rusd.burn(alice, 100e18);

        assertEq(rusd.totalSupply(), 0);
    }

    function test_burnRevertsOnInsufficientBalance() public {
        vm.prank(vault);
        rusd.mint(alice, 50e18);

        vm.prank(vault);
        vm.expectRevert();
        rusd.burn(alice, 51e18);
    }

    // --- Standard ERC-20 behaviour ---

    function test_transferBetweenUsers() public {
        address bob = makeAddr("bob");
        vm.prank(vault);
        rusd.mint(alice, 100e18);

        vm.prank(alice);
        rusd.transfer(bob, 30e18);

        assertEq(rusd.balanceOf(alice), 70e18);
        assertEq(rusd.balanceOf(bob),   30e18);
    }

    function test_approveAndTransferFrom() public {
        address bob = makeAddr("bob");
        vm.prank(vault);
        rusd.mint(alice, 100e18);

        vm.prank(alice);
        rusd.approve(bob, 50e18);

        vm.prank(bob);
        rusd.transferFrom(alice, bob, 50e18);

        assertEq(rusd.balanceOf(alice), 50e18);
        assertEq(rusd.balanceOf(bob),   50e18);
    }
}
