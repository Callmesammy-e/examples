// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SchedulerResponse
 * @notice Response contract for handling scheduled action execution
 */
contract SchedulerResponse {
    event ScheduledActionExecuted(
        uint256 timestamp,
        string action,
        uint256 executionTime
    );

    // State to track responses
    mapping(string => uint256) public actionExecuted;

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
     * @notice Execute a scheduled action
     * @param timestamp The timestamp when the action was scheduled
     * @param action The action description/identifier
     * @dev This function matches the response_function signature in drosera.toml
     */
    function executeScheduledAction(
        uint256 timestamp,
        string calldata action
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        actionExecuted[action] = timestamp;
        emit ScheduledActionExecuted(timestamp, action, block.timestamp);
    }

    // View function for testing
    function wasActionExecuted(
        string calldata action
    ) external view returns (bool) {
        return actionExecuted[action] > 0;
    }

    function getActionExecutionTime(
        string calldata action
    ) external view returns (uint256) {
        return actionExecuted[action];
    }
}
