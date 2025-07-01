// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SuddenBalanceDropResponse
 * @notice Response contract for handling sudden balance drop alerts
 */
contract SuddenBalanceDropResponse {
    event BalanceDropHandled(
        address indexed vault,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 timestamp
    );

    // State to track responses
    mapping(address => bool) public balanceDropHandled;

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
     * @notice Handle a sudden balance drop
     * @param vault The vault address that experienced the drop
     * @param oldBalance The previous balance
     * @param newBalance The current balance
     * @dev This function matches the response_function signature in drosera.toml
     */
    function handleBalanceDrop(
        address vault,
        uint256 oldBalance,
        uint256 newBalance
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        balanceDropHandled[vault] = true;
        emit BalanceDropHandled(vault, oldBalance, newBalance, block.timestamp);
    }

    // View function for testing
    function wasBalanceDropHandled(address vault) external view returns (bool) {
        return balanceDropHandled[vault];
    }
}
