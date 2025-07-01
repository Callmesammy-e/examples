// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockFeeContract
 * @notice Simple mock contract for testing fee monitoring
 */
contract MockFeeContract {
    uint256 public performanceFee = 1000; // 10% initially
    
    function setPerformanceFee(uint256 _fee) external {
        performanceFee = _fee;
    }
}