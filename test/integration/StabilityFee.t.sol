// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "./Base.t.sol";

/// @notice Integration: stability fee accrues over time; closing requires extra rUSD.
contract StabilityFeeTest is Base {
    uint256 constant COLLATERAL  = 100 ether; // plenty of buffer
    uint256 constant MINT_AMOUNT = 100 ether; // $500 collateral, $100 debt → 500%

    function setUp() public override {
        super.setUp();
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(MINT_AMOUNT);
        vm.stopPrank();
    }

    function test_debtGrowsOverTime() public {
        uint256 debtInitial = vault.debtWithFee(alice);

        // Advance one year
        vm.warp(block.timestamp + 365 days);

        uint256 debtAfterYear = vault.debtWithFee(alice);
        assertGt(debtAfterYear, debtInitial);
    }

    function test_debtGrowsApproximately5PercentPerYear() public {
        uint256 debtInitial = vault.debtWithFee(alice);

        vm.warp(block.timestamp + 365 days);

        uint256 debtAfterYear = vault.debtWithFee(alice);
        // Expect ~5% growth: within 1% tolerance
        uint256 expected = debtInitial * 105 / 100;
        assertApproxEqRel(debtAfterYear, expected, 0.01e18); // 1% tolerance
    }

    function test_closingAfterFeeRequiresMoreRUSD() public {
        // Advance time so fee accrues
        vm.warp(block.timestamp + 30 days);

        uint256 owedAfterFee = vault.debtWithFee(alice);
        assertGt(owedAfterFee, MINT_AMOUNT);

        // Alice needs more rUSD than she minted to close
        // Fund alice with extra rUSD via bob's vault
        vm.startPrank(bob);
        vault.open{value: 100 ether}();
        vault.mint(owedAfterFee - MINT_AMOUNT + 1 ether); // margin
        rusd.transfer(alice, owedAfterFee - MINT_AMOUNT + 1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.burn(owedAfterFee);
        vault.close();
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault.positions(alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_debtDoesNotGrowWithoutTimePassing() public {
        uint256 debtBefore = vault.debtWithFee(alice);
        uint256 debtAfter  = vault.debtWithFee(alice);
        assertEq(debtBefore, debtAfter);
    }

    function test_stabilityFeeIncreasesRatioDenominator() public {
        uint256 ratioBefore = vault.collateralRatio(alice);

        vm.warp(block.timestamp + 365 days);

        uint256 ratioAfter = vault.collateralRatio(alice);
        // More debt → lower collateral ratio
        assertLt(ratioAfter, ratioBefore);
    }
}
