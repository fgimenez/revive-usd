// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "./Base.t.sol";

/// @notice Integration: collateral ratio enforcement on mint and withdraw.
contract CollateralRatioTest is Base {
    // 10 PAS at $5 = $50 collateral value
    // Max rUSD at 150%: $50 * 100/150 = 33.33 rUSD
    uint256 constant COLLATERAL = 10 ether;

    function test_collateralRatioAfterOpen() public {
        vm.prank(alice);
        vault.open{value: COLLATERAL}();

        // No debt → ratio is effectively infinite; use a sentinel (type(uint256).max or 0)
        // Convention: 0 debt returns type(uint256).max
        assertEq(vault.collateralRatio(alice), type(uint256).max);
    }

    function test_collateralRatioAfterMint() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(20 ether); // $20 debt, $50 collateral → 250%
        vm.stopPrank();

        // ratio = collateral * price * 100 / debt = 10 * 5 * 100 / 20 = 250
        assertEq(vault.collateralRatio(alice), 250);
    }

    function test_mintRevertsWhenBelowMinRatio() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        // Max at 150% is 33.33 rUSD; minting 34 rUSD should revert
        vm.expectRevert();
        vault.mint(34 ether);
        vm.stopPrank();
    }

    function test_mintUpToMinRatioSucceeds() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(33 ether); // just under the limit
        vm.stopPrank();

        assertGe(vault.collateralRatio(alice), vault.MIN_RATIO());
    }

    function test_withdrawRevertsWhenRatioBreached() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(33 ether); // near the limit

        // Withdrawing any collateral now would breach 150%
        vm.expectRevert();
        vault.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_withdrawSucceedsWithEnoughBuffer() public {
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(10 ether); // $10 debt, $50 collateral → 500% ratio, plenty of buffer

        vault.withdraw(5 ether); // removes $25, leaving $25 collateral → still 250%
        vm.stopPrank();

        (uint256 collateral,,) = vault.positions(alice);
        assertEq(collateral, 5 ether);
        assertGe(vault.collateralRatio(alice), vault.MIN_RATIO());
    }

    function test_maxMintableMatchesLimit() public {
        vm.prank(alice);
        vault.open{value: COLLATERAL}();

        uint256 maxMint = vault.maxMintable(alice);
        // Should be floor(10 * 5e18 / 1e18 * 100 / 150) = 33 ether (approx)
        assertGt(maxMint, 0);

        // Minting exactly maxMintable must succeed
        vm.prank(alice);
        vault.mint(maxMint);

        assertGe(vault.collateralRatio(alice), vault.MIN_RATIO());
    }
}
