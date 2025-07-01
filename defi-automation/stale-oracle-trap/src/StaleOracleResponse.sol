// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StaleOracleResponse
 * @notice Response contract for handling stale oracle alerts
 * @dev Handles responses when oracle data becomes stale or outdated
 */
contract StaleOracleResponse {
    // Events for tracking response actions
    event StaleOracleAlerted(
        address indexed oracle,
        int256 price,
        uint256 updatedAt,
        uint256 staleness,
        uint256 timestamp
    );

    // State to track responses
    mapping(address => bool) public oracleAlerted;

    // Simple access control
    address public trapConfig;

    constructor(address _trapConfig) {
        trapConfig = _trapConfig;
    }

    modifier onlyTrapConfig() {
        require(msg.sender == trapConfig, "Only TrapConfig can call this");
        _;
    }

    /**
     * @notice Alert about a stale oracle
     * @param oracle The oracle address that is stale
     * @param price The last known price from the oracle
     * @param updatedAt The timestamp when the oracle was last updated
     * @param staleness How long the oracle has been stale (in seconds)
     * @dev This function matches the response_function signature in drosera.toml
     */
    function alertStaleOracle(
        address oracle,
        int256 price,
        uint256 updatedAt,
        uint256 staleness
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        // Record that oracle was alerted
        oracleAlerted[oracle] = true;

        emit StaleOracleAlerted(
            oracle,
            price,
            updatedAt,
            staleness,
            block.timestamp
        );

        // In a real implementation, this could:
        // 1. Pause protocols that depend on this oracle
        // 2. Switch to backup oracles
        // 3. Alert external monitoring systems
        // 4. Trigger governance proposals
    }

    // View function for testing
    function wasOracleAlerted(address oracle) external view returns (bool) {
        return oracleAlerted[oracle];
    }
}
