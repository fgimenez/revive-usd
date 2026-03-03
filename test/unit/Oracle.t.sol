// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/Oracle.sol";

contract OracleTest is Test {
    Oracle internal oracle;

    address internal owner    = address(this);
    address internal attacker = makeAddr("attacker");

    uint256 constant INITIAL_PRICE = 5e18; // $5.00

    function setUp() public {
        oracle = new Oracle(INITIAL_PRICE);
    }

    // --- Initial state ---

    function test_initialPrice() public view {
        assertEq(oracle.getPrice(), INITIAL_PRICE);
    }

    function test_initialLastUpdated() public view {
        assertEq(oracle.lastUpdated(), block.timestamp);
    }

    // --- setPrice ---

    function test_setPriceOnlyOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        oracle.setPrice(4e18);
    }

    function test_setPriceUpdatesPrice() public {
        oracle.setPrice(7e18);
        assertEq(oracle.getPrice(), 7e18);
    }

    function test_setPriceUpdatesLastUpdated() public {
        vm.warp(block.timestamp + 1 hours);
        oracle.setPrice(6e18);
        assertEq(oracle.lastUpdated(), block.timestamp);
    }

    function test_setPriceToZeroAllowed() public {
        // Zero price is technically allowed (would make all positions liquidatable)
        oracle.setPrice(0);
        assertEq(oracle.getPrice(), 0);
    }

    function test_setPriceMultipleTimes() public {
        oracle.setPrice(4e18);
        oracle.setPrice(3e18);
        oracle.setPrice(10e18);
        assertEq(oracle.getPrice(), 10e18);
    }

    // --- getPrice ---

    function test_getPriceReturnsCurrentPrice() public {
        oracle.setPrice(42e18);
        assertEq(oracle.getPrice(), 42e18);
    }

    // --- Fuzz ---

    function testFuzz_setPriceAnyValue(uint256 price) public {
        oracle.setPrice(price);
        assertEq(oracle.getPrice(), price);
    }
}
