// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "./RUSD.sol";
import "./Oracle.sol";

/// @title ReviveUSD Vault
/// @notice CDP engine: lock native PAS as collateral, mint rUSD stablecoin.
///         Compiled to PolkaVM via --resolc; runs natively on Polkadot Hub.
contract Vault {
    // --- Constants ---

    /// @notice Minimum collateral ratio to mint or keep a position open (150%)
    uint256 public constant MIN_RATIO = 150;
    /// @notice Collateral ratio below which a position can be liquidated (130%)
    uint256 public constant LIQ_THRESHOLD = 130;
    /// @notice Percentage of collateral bonus paid to liquidators (10%)
    uint256 public constant LIQ_PENALTY = 10;

    // 5% APY expressed as a per-second additive rate in ray units (1e27).
    // rate_per_second = 0.05 / (365 * 24 * 3600) ≈ 1.5854896e-9
    // in ray: 1.5854896e-9 * 1e27 = 1_585_489_599_188_229_325
    uint256 public constant STABILITY_FEE_RATE = 1_585_489_599_188_229_325;

    // --- Immutables ---

    RUSD   public immutable rusd;
    Oracle public immutable oracle;

    // --- State ---

    struct Position {
        uint256 collateral; // PAS deposited (wei)
        uint256 debt;       // rUSD owed at last touch, in absolute terms
        uint256 feeIndex;   // snapshot of feeAccumulator at last touch (ray)
    }

    mapping(address => Position) public positions;

    /// @notice Global fee accumulator in ray (1e27), starts at 1e27 = 1.0
    uint256 public feeAccumulator;
    /// @notice Timestamp of the last global fee accrual
    uint256 public lastFeeUpdate;

    // --- Events ---

    event Opened(address indexed user, uint256 collateral);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event Closed(address indexed user);
    event Liquidated(address indexed user, address indexed liquidator, uint256 collateralSeized);

    // --- Errors ---

    error InsufficientCollateralRatio();
    error NotLiquidatable();
    error NoPosition();
    error PositionExists();
    error ZeroAmount();

    // --- Constructor ---

    constructor(address _rusd, address _oracle) {
        rusd   = RUSD(_rusd);
        oracle = Oracle(_oracle);
        feeAccumulator = 1e27;
        lastFeeUpdate  = block.timestamp;
    }

    // --- External: lifecycle ---

    /// @notice Open a new position by depositing PAS collateral.
    function open() external payable {
        if (positions[msg.sender].collateral > 0) revert PositionExists();
        if (msg.value == 0) revert ZeroAmount();

        _accrueGlobalFee();

        positions[msg.sender] = Position({
            collateral: msg.value,
            debt:       0,
            feeIndex:   feeAccumulator
        });

        emit Opened(msg.sender, msg.value);
    }

    /// @notice Add more PAS collateral to an existing position.
    function deposit() external payable {
        if (positions[msg.sender].collateral == 0) revert NoPosition();
        if (msg.value == 0) revert ZeroAmount();

        _accrueGlobalFee();
        _touchPosition(msg.sender);

        positions[msg.sender].collateral += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Remove PAS collateral, provided the ratio stays above MIN_RATIO.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (pos.collateral == 0) revert NoPosition();
        require(pos.collateral >= amount, "Vault: insufficient collateral");

        _accrueGlobalFee();
        _touchPosition(msg.sender);

        pos.collateral -= amount;

        if (pos.debt > 0 && collateralRatio(msg.sender) < MIN_RATIO) {
            revert InsufficientCollateralRatio();
        }

        _sendPAS(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Mint rUSD against existing collateral, up to MIN_RATIO.
    function mint(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (pos.collateral == 0) revert NoPosition();

        _accrueGlobalFee();
        _touchPosition(msg.sender);

        pos.debt += amount;

        if (collateralRatio(msg.sender) < MIN_RATIO) revert InsufficientCollateralRatio();

        rusd.mint(msg.sender, amount);
        emit Minted(msg.sender, amount);
    }

    /// @notice Burn rUSD to reduce debt.
    function burn(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (pos.collateral == 0) revert NoPosition();

        _accrueGlobalFee();
        _touchPosition(msg.sender);

        require(amount <= pos.debt, "Vault: amount exceeds debt");

        pos.debt -= amount;

        rusd.burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    /// @notice Close a debt-free position and reclaim all collateral.
    function close() external {
        Position storage pos = positions[msg.sender];
        if (pos.collateral == 0) revert NoPosition();

        _accrueGlobalFee();
        _touchPosition(msg.sender);

        require(pos.debt == 0, "Vault: repay debt first");

        uint256 collateral = pos.collateral;
        delete positions[msg.sender];

        _sendPAS(msg.sender, collateral);
        emit Closed(msg.sender);
    }

    /// @notice Liquidate an undercollateralized position.
    ///         Caller burns the position's debt and receives all collateral.
    function liquidate(address user) external {
        if (positions[user].collateral == 0) revert NoPosition();

        _accrueGlobalFee();
        _touchPosition(user);

        if (collateralRatio(user) >= LIQ_THRESHOLD) revert NotLiquidatable();

        uint256 debt       = positions[user].debt;
        uint256 collateral = positions[user].collateral;

        delete positions[user];

        rusd.burn(msg.sender, debt);
        _sendPAS(msg.sender, collateral);

        emit Liquidated(user, msg.sender, collateral);
    }

    // --- Views ---

    /// @notice Current collateral ratio of a position (e.g. 150 = 150%).
    ///         Returns type(uint256).max when debt is zero.
    function collateralRatio(address user) public view returns (uint256) {
        uint256 debt = debtWithFee(user);
        if (debt == 0) return type(uint256).max;
        // ratio = (collateral * price / 1e18) * 100 / debt
        return positions[user].collateral * oracle.getPrice() / 1e18 * 100 / debt;
    }

    /// @notice rUSD debt of a position including accrued stability fee.
    function debtWithFee(address user) public view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.debt == 0) return 0;
        return pos.debt * _currentAccumulator() / pos.feeIndex;
    }

    /// @notice Maximum additional rUSD mintable without breaching MIN_RATIO.
    function maxMintable(address user) public view returns (uint256) {
        Position memory pos = positions[user];
        uint256 maxDebt     = pos.collateral * oracle.getPrice() / 1e18 * 100 / MIN_RATIO;
        uint256 currentDebt = debtWithFee(user);
        if (maxDebt <= currentDebt) return 0;
        return maxDebt - currentDebt;
    }

    // --- Internals ---

    /// @dev Advance the global fee accumulator to the current timestamp.
    function _accrueGlobalFee() internal {
        uint256 elapsed = block.timestamp - lastFeeUpdate;
        if (elapsed == 0) return;
        feeAccumulator += feeAccumulator * STABILITY_FEE_RATE * elapsed / 1e27;
        lastFeeUpdate   = block.timestamp;
    }

    /// @dev Read-only version of the accumulator at the current block.
    function _currentAccumulator() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - lastFeeUpdate;
        return feeAccumulator + feeAccumulator * STABILITY_FEE_RATE * elapsed / 1e27;
    }

    /// @dev Update a position's debt to current terms and reset its fee index.
    ///      Must be called after _accrueGlobalFee() and before any debt mutation.
    function _touchPosition(address user) internal {
        Position storage pos = positions[user];
        if (pos.debt > 0 && pos.feeIndex > 0) {
            pos.debt = pos.debt * feeAccumulator / pos.feeIndex;
        }
        pos.feeIndex = feeAccumulator;
    }

    /// @dev Transfer PAS (native token) to an address, reverting on failure.
    function _sendPAS(address to, uint256 amount) internal {
        (bool ok,) = payable(to).call{value: amount}("");
        require(ok, "Vault: PAS transfer failed");
    }
}
