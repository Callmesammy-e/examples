// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LiquidityPoolHealthResponse
 * @notice Response contract for handling unhealthy liquidity pool alerts
 */
contract LiquidityPoolHealthResponse {
    struct PoolHealthAlert {
        address pool;
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint256 minThreshold;
        uint256 currentRatio;
        bool isHealthy;
    }

    event UnhealthyPoolsHandled(uint256 poolCount, uint256 timestamp);

    // State to track responses
    mapping(address => bool) public poolHealthHandled;

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
     * @notice Handle unhealthy liquidity pools
     * @param alerts Array of pool health alerts
     * @dev This function matches the response_function signature in drosera.toml
     */
    function handleUnhealthyPools(
        PoolHealthAlert[] calldata alerts
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        for (uint256 i = 0; i < alerts.length; i++) {
            poolHealthHandled[alerts[i].pool] = true;
        }
        emit UnhealthyPoolsHandled(alerts.length, block.timestamp);
    }

    // View function for testing
    function wasPoolHealthHandled(address pool) external view returns (bool) {
        return poolHealthHandled[pool];
    }
}
