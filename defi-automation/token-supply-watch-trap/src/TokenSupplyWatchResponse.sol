// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenSupplyWatchResponse
 * @notice Response contract for handling suspicious token supply changes
 */
contract TokenSupplyWatchResponse {
    struct SupplyAlert {
        address token;
        uint256 oldSupply;
        uint256 newSupply;
    }

    event SuspiciousSupplyChangeHandled(uint256 alertCount, uint256 timestamp);

    // State to track responses
    mapping(address => bool) public supplyChangeHandled;

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
     * @notice Handle suspicious supply changes for multiple tokens
     * @param alerts Array of supply alerts with token, old and new supply
     * @dev This function matches the response_function signature in drosera.toml
     */
    function handleSuspiciousSupplyChange(
        SupplyAlert[] calldata alerts
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        for (uint256 i = 0; i < alerts.length; i++) {
            supplyChangeHandled[alerts[i].token] = true;
        }
        emit SuspiciousSupplyChangeHandled(alerts.length, block.timestamp);
    }

    // View function for testing
    function wasSupplyChangeHandled(
        address token
    ) external view returns (bool) {
        return supplyChangeHandled[token];
    }
}
