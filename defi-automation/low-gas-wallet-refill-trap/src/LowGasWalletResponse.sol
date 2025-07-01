// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LowGasWalletResponse
 * @notice Response contract for handling wallet refill requests
 */
contract LowGasWalletResponse {
    event WalletRefilled(
        address indexed wallet,
        uint256 amount,
        uint256 timestamp
    );

    // State to track responses
    mapping(address => bool) public walletRefilled;

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
     * @notice Refill a wallet with ETH
     * @param wallet The wallet address to refill
     * @param amount The amount of ETH to send
     * @dev This function matches the response_function signature in drosera.toml
     */
    function refillWallet(
        address wallet,
        uint256 amount
    ) external onlyTrapConfig {
        // NOTE: This is a simplified example of a response but can be extended to real world use cases.
        walletRefilled[wallet] = true;
        emit WalletRefilled(wallet, amount, block.timestamp);
    }

    // View function for testing
    function wasWalletRefilled(address wallet) external view returns (bool) {
        return walletRefilled[wallet];
    }
}
