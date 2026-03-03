// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RUSD is ERC20, Ownable {
    address public vault;

    constructor() ERC20("ReviveUSD", "rUSD") Ownable(msg.sender) {}

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == vault, "RUSD: not vault");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == vault, "RUSD: not vault");
        _burn(from, amount);
    }
}
