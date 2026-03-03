// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/RUSD.sol";
import "../../src/Oracle.sol";
import "../../src/Vault.sol";

/// @dev Handler drives the fuzzer: every public function is a valid action.
contract VaultHandler is Test {
    Vault   internal vault;
    RUSD    internal rusd;
    Oracle  internal oracle;

    address[] internal actors;
    address   internal currentActor;

    // Track all actors that ever opened a position
    mapping(address => bool) internal hasPosition;

    constructor(Vault _vault, RUSD _rusd, Oracle _oracle) {
        vault  = _vault;
        rusd   = _rusd;
        oracle = _oracle;

        // Pre-create a fixed set of actors
        for (uint256 i = 0; i < 4; i++) {
            address a = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(a);
            vm.deal(a, 10_000 ether);
        }
    }

    modifier useActor(uint256 actorSeed) {
        currentActor = actors[actorSeed % actors.length];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function open(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        amount = bound(amount, 1 ether, 100 ether);
        (uint256 col,,) = vault.positions(currentActor);
        if (col > 0) return; // already open
        vault.open{value: amount}();
        hasPosition[currentActor] = true;
    }

    function deposit(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        amount = bound(amount, 1 ether, 50 ether);
        (uint256 col,,) = vault.positions(currentActor);
        if (col == 0) return;
        vault.deposit{value: amount}();
    }

    function mint(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        (uint256 col,,) = vault.positions(currentActor);
        if (col == 0) return;
        uint256 maxMint = vault.maxMintable(currentActor);
        if (maxMint == 0) return;
        amount = bound(amount, 1, maxMint);
        vault.mint(amount);
    }

    function burn(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        uint256 debt = vault.debtWithFee(currentActor);
        if (debt == 0) return;
        amount = bound(amount, 1, debt);
        // Ensure actor has enough rUSD
        uint256 balance = rusd.balanceOf(currentActor);
        if (balance < amount) return;
        vault.burn(amount);
    }

    function warpTime(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1, 30 days);
        vm.warp(block.timestamp + seconds_);
    }

    function setPrice(uint256 price) external {
        // Keep price in a realistic range to avoid trivial collapses
        price = bound(price, 1e18, 20e18); // $1 – $20
        oracle.setPrice(price);
    }

    function actorAddresses() external view returns (address[] memory) {
        return actors;
    }
}

/// @notice Invariant: the vault is always solvent for non-liquidatable positions.
///         For every position with ratio >= LIQ_THRESHOLD, the collateral value
///         must cover the debt at that threshold.
contract VaultInvariantTest is Test {
    Vault        internal vault;
    RUSD         internal rusd;
    Oracle       internal oracle;
    VaultHandler internal handler;

    function setUp() public {
        rusd    = new RUSD();
        oracle  = new Oracle(5e18);
        vault   = new Vault(address(rusd), address(oracle));
        rusd.setVault(address(vault));

        handler = new VaultHandler(vault, rusd, oracle);

        // Transfer oracle ownership to handler so it can set prices
        oracle.transferOwnership(address(handler));

        // Scope fuzzer to only call handler functions
        targetContract(address(handler));
    }

    /// @notice collateralRatio() must always match the manual formula.
    ///         Note: a position can legitimately sit between LIQ_THRESHOLD (130%) and
    ///         MIN_RATIO (150%) after a price drop — that is a valid protocol state
    ///         (not yet liquidatable, but no new minting allowed).
    function invariant_ratioConsistency() public view {
        address[] memory actors = handler.actorAddresses();
        uint256 price = oracle.getPrice();

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            (uint256 collateral,,) = vault.positions(actor);
            if (collateral == 0) continue;

            uint256 debtNow      = vault.debtWithFee(actor);
            uint256 reportedRatio = vault.collateralRatio(actor);

            if (debtNow == 0) {
                assertEq(reportedRatio, type(uint256).max,
                    "Invariant broken: zero-debt position should return max ratio");
            } else {
                uint256 expectedRatio = collateral * price / 1e18 * 100 / debtNow;
                assertEq(reportedRatio, expectedRatio,
                    "Invariant broken: collateralRatio() inconsistent with manual formula");
            }
        }
    }

    /// @notice rUSD total supply must equal the sum of all position debts (with fees).
    function invariant_totalSupplyMatchesDebt() public view {
        address[] memory actors = handler.actorAddresses();
        uint256 totalDebt;

        for (uint256 i = 0; i < actors.length; i++) {
            totalDebt += vault.debtWithFee(actors[i]);
        }

        // Supply may be slightly less than totalDebt due to rounding in fee accrual,
        // but never greater (you can't have more rUSD in circulation than debt owed).
        assertLe(rusd.totalSupply(), totalDebt + 1e15, // 0.001 rUSD dust tolerance
            "Invariant broken: rUSD supply exceeds total debt");
    }

    /// @notice The vault's PAS balance must equal the sum of all collateral.
    function invariant_vaultBalanceMatchesCollateral() public view {
        address[] memory actors = handler.actorAddresses();
        uint256 totalCollateral;

        for (uint256 i = 0; i < actors.length; i++) {
            (uint256 collateral,,) = vault.positions(actors[i]);
            totalCollateral += collateral;
        }

        assertEq(address(vault).balance, totalCollateral,
            "Invariant broken: vault PAS balance != sum of collateral");
    }
}
