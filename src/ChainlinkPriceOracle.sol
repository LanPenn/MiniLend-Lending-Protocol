// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RiskManager.sol";
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256 answer,
            uint256,
            uint256,
            uint80
        );
        function decimals() external view returns (uint8);
}


/**
 * @title Simple Price Oracle
 * @notice A simplified oracle for providing asset prices
 * @dev Prices are manually set by owner (mock oracle for testing)
 */
contract ChainlinkPriceOracle is Ownable {
    RiskManager public riskManager;

    constructor(RiskManager _riskManager) Ownable(msg.sender) {
        riskManager = _riskManager;
    }

    function getPrice(address token) public view returns (uint256) {
        address feed = riskManager.priceFeeds(token);
        require(feed != address(0), "No feed");

        AggregatorV3Interface aggregator = AggregatorV3Interface(feed);

        (, int256 price,, uint256 updatedAt,) = aggregator.latestRoundData();

        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt < 1 hours, "Stale price");

        uint8 decimals = aggregator.decimals();

        return uint256(price) * (10 ** (18 - decimals));
    }
}