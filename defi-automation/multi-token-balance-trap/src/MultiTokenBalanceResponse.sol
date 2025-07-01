// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MultiTokenBalanceResponse
 * @notice Response contract for handling multiple token balance refill requests
 */
contract MultiTokenBalanceResponse {
    struct RefillRequest {
        address token;
        address account;
        uint256 currentBalance;
        uint256 targetBalance;
    }

    event TokenRefillsHandled(uint256 requestCount, uint256 timestamp);

    // State to track responses
    mapping(address => mapping(address => bool)) public refillHandled; // token => account => handled

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
     * @notice Handle multiple token balance refill requests
     * @param requests Array of refill requests with token, account, current and target balances
     * @dev This function matches the response_function signature in drosera.toml
     */
    function refillTokenBalances(
        RefillRequest[] calldata requests
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        for (uint256 i = 0; i < requests.length; i++) {
            RefillRequest memory request = requests[i];
            refillHandled[request.token][request.account] = true;
        }
        emit TokenRefillsHandled(requests.length, block.timestamp);
    }

    // View function for testing
    function wasRefillHandled(
        address token,
        address account
    ) external view returns (bool) {
        return refillHandled[token][account];
    }
}
