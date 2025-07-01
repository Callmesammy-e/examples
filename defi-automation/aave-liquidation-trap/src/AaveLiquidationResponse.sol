// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AaveLiquidationResponse
 * @notice Response contract for handling AAVE liquidation alerts
 */
contract AaveLiquidationResponse {
    event LiquidationTriggered(address indexed user, uint256 timestamp);

    // State to track if response was triggered
    mapping(address => bool) public liquidationTriggered;

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
     * @notice Liquidate a specific position
     * @param user The user whose position to liquidate
     * @param collateralAsset The collateral asset to liquidate
     * @param debtAsset The debt asset to repay
     * @param debtToCover The amount of debt to cover
     * @dev This function matches the response_function signature in drosera.toml
     */
    function liquidatePosition(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        liquidationTriggered[user] = true;
        emit LiquidationTriggered(user, block.timestamp);
    }

    // View function for testing
    function wasLiquidationTriggered(
        address user
    ) external view returns (bool) {
        return liquidationTriggered[user];
    }
}
