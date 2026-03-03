// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Oracle is Ownable {
    uint256 public price;
    uint256 public lastUpdated;

    constructor(uint256 _initialPrice) Ownable(msg.sender) {
        price = _initialPrice;
        lastUpdated = block.timestamp;
    }

    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
        lastUpdated = block.timestamp;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }
}
