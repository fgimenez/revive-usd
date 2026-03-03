// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "./Base.t.sol";

/// @notice Integration: price drop makes position liquidatable; liquidator profits.
contract LiquidationTest is Base {
    // Alice opens with 10 PAS at $5 = $50 collateral, mints 33 rUSD (≈150%)
    uint256 constant COLLATERAL  = 10 ether;
    uint256 constant MINT_AMOUNT = 33 ether;

    // Dropped price that puts alice below 130% liquidation threshold
    // ratio = collateral * price * 100 / debt
    // 130 = 10 * newPrice * 100 / 33  →  newPrice = 130 * 33 / 1000 = 4.29
    // Use $4 to be safely below threshold
    uint256 constant LOW_PRICE = 4e18;

    function setUp() public override {
        super.setUp();

        // Alice opens a position near the min ratio
        vm.startPrank(alice);
        vault.open{value: COLLATERAL}();
        vault.mint(MINT_AMOUNT);
        vm.stopPrank();

        // Bob acquires rUSD to act as liquidator
        // (deal him rUSD directly via the vault — he opens his own position)
        vm.startPrank(bob);
        vault.open{value: 100 ether}();
        vault.mint(MINT_AMOUNT);
        vm.stopPrank();
    }

    function test_positionNotLiquidatableAtInitialPrice() public {
        vm.expectRevert();
        vm.prank(bob);
        vault.liquidate(alice);
    }

    function test_priceDropMakesPositionLiquidatable() public {
        oracle.setPrice(LOW_PRICE);

        // ratio = 10 * 4 * 100 / 33 ≈ 121% < 130% threshold
        assertLt(vault.collateralRatio(alice), vault.LIQ_THRESHOLD());
    }

    function test_liquidatorReceivesCollateralAtDiscount() public {
        oracle.setPrice(LOW_PRICE);

        uint256 bobPASBefore  = bob.balance;
        uint256 aliceDebt     = vault.debtWithFee(alice);

        vm.startPrank(bob);
        rusd.approve(address(vault), aliceDebt);
        vault.liquidate(alice);
        vm.stopPrank();

        // Bob should receive alice's collateral + 10% penalty bonus
        uint256 bobPASAfter = bob.balance;
        assertGt(bobPASAfter, bobPASBefore);
    }

    function test_liquidatedPositionIsDeleted() public {
        oracle.setPrice(LOW_PRICE);

        uint256 aliceDebt = vault.debtWithFee(alice);
        vm.startPrank(bob);
        rusd.approve(address(vault), aliceDebt);
        vault.liquidate(alice);
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault.positions(alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_liquidatorRUSDIsReduced() public {
        oracle.setPrice(LOW_PRICE);

        uint256 aliceDebt = vault.debtWithFee(alice);
        uint256 bobRUSDBefore = rusd.balanceOf(bob);

        vm.startPrank(bob);
        rusd.approve(address(vault), aliceDebt);
        vault.liquidate(alice);
        vm.stopPrank();

        assertEq(rusd.balanceOf(bob), bobRUSDBefore - aliceDebt);
    }
}
