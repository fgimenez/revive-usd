// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "./Base.t.sol";

/// @notice Integration: full open → mint → burn → close lifecycle.
contract OpenAndCloseTest is Base {
    // 10 PAS collateral at $5/PAS → $50 collateral value
    // At 150% min ratio: max rUSD = $50 * 100/150 ≈ 33.33 rUSD
    uint256 constant COLLATERAL = 10 ether;
    uint256 constant MINT_AMOUNT = 33 ether; // safely under max

    function test_openCreatesPosition() public {
        vm.prank(alice);
        vault.open{value: COLLATERAL}();

        (uint256 collateral, uint256 debt,) = vault.positions(alice);
        assertEq(collateral, COLLATERAL);
        assertEq(debt, 0);
    }

    function test_openThenMintIssuesRUSD() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(MINT_AMOUNT);
        vm.stopPrank();

        assertEq(rusd.balanceOf(alice), MINT_AMOUNT);
        (, uint256 debt,) = vault.positions(alice);
        assertGt(debt, 0);
    }

    function test_burnReducesDebt() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(MINT_AMOUNT);
        uint256 balanceBefore = rusd.balanceOf(alice);

        vault.burn(MINT_AMOUNT / 2);
        vm.stopPrank();

        assertEq(rusd.balanceOf(alice), balanceBefore - MINT_AMOUNT / 2);
    }

    function test_closeReturnsCollateralAndBurnsDebt() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(MINT_AMOUNT);

        uint256 pasBefore = alice.balance;
        vault.burn(MINT_AMOUNT); // repay all debt first
        vault.close();
        vm.stopPrank();

        assertEq(rusd.balanceOf(alice), 0);
        assertEq(alice.balance, pasBefore + COLLATERAL);
        (uint256 collateral, uint256 debt,) = vault.positions(alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_depositIncreasesCollateral() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.deposit{value: COLLATERAL}();
        vm.stopPrank();

        (uint256 collateral,,) = vault.positions(alice);
        assertEq(collateral, COLLATERAL * 2);
    }

    function test_withdrawReducesCollateral() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();

        uint256 pasBefore = alice.balance;
        vault.withdraw(COLLATERAL / 2);
        vm.stopPrank();

        (uint256 collateral,,) = vault.positions(alice);
        assertEq(collateral, COLLATERAL / 2);
        assertEq(alice.balance, pasBefore + COLLATERAL / 2);
    }

    function test_cannotOpenTwice() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vm.expectRevert();
        vault.open{value: COLLATERAL}();
        vm.stopPrank();
    }
}
