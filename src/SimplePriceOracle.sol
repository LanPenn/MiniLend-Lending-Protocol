// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Simple Price Oracle
 * @notice A simplified oracle for providing asset prices
 * @dev Prices are manually set by owner (mock oracle for testing)
 */
contract SimplePriceOracle is Ownable {
    mapping(address => uint256) public prices;

    event PriceUpdated(address token, uint256 price);

    constructor() Ownable(msg.sender) {}


/**
 * @notice Set price for a given token
 * @param token The token address
 * @param price The price of the token
 * @dev Only callable by owner, simulates off-chain price feed
 */
    function setPrice(address token, uint256 price) external onlyOwner {
        require(price > 0, "invalid price");
        prices[token] = price;
        emit PriceUpdated(token, price);
    }


/**
 * @notice Get the price of a token
 * @param token The token address
 * @return price The current price of the token
 * @dev Reverts if price is not set
 */
    function getPrice(address token) external view returns (uint256) {
        uint256 price = prices[token];
        require(price > 0, "price not set");
        return price;
    }
}