// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ImplementationSwapResponse
 * @notice Response contract for handling proxy upgrade alerts
 */
contract ImplementationSwapResponse {
    event ProxyUpgradeHandled(
        address indexed proxy,
        address oldImpl,
        address newImpl,
        string changeType,
        uint256 timestamp
    );

    // State to track responses
    mapping(address => bool) public upgradeHandled;

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
     * @notice Handle a proxy upgrade
     * @param proxy The proxy contract address
     * @param oldImplementation The old implementation address
     * @param newImplementation The new implementation address
     * @param changeType Description of the change type
     * @dev This function matches the response_function signature in drosera.toml
     */
    function handleProxyUpgrade(
        address proxy,
        address oldImplementation,
        address newImplementation,
        string calldata changeType
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        upgradeHandled[proxy] = true;
        emit ProxyUpgradeHandled(
            proxy,
            oldImplementation,
            newImplementation,
            changeType,
            block.timestamp
        );
    }

    // View function for testing
    function wasUpgradeHandled(address proxy) external view returns (bool) {
        return upgradeHandled[proxy];
    }
}
