// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title FeeViolationResponse
 * @notice Response contract for handling excessive fee violations
 */
contract FeeViolationResponse {
    event ViolationHandled(uint256 feeValue, uint256 timestamp);

    // State to track responses
    mapping(uint256 => bool) public violationHandled;

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
     * @notice Handle a fee violation with the fee value
     * @param feeValue The excessive fee value that was detected
     * @dev This function matches the response_function signature in drosera.toml
     */
    function handleViolation(uint256 feeValue) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        violationHandled[feeValue] = true;
        emit ViolationHandled(feeValue, block.timestamp);
    }

    // View function for testing
    function wasViolationHandled(
        uint256 feeValue
    ) external view returns (bool) {
        return violationHandled[feeValue];
    }
}
