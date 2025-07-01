// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

/**
 * @title SchedulerTrap
 * @notice Simple time-based scheduler that triggers at regular intervals
 * @dev Practical trap for periodic maintenance tasks
 */
contract SchedulerTrap is ITrap {
    uint256 constant INTERVAL_HOURS = 24; // Trigger every 24 hours
    uint256 constant INTERVAL_SECONDS = INTERVAL_HOURS * 3600;

    struct ScheduleData {
        uint256 blockNumber;
        uint256 timestamp;
        uint256 lastTrigger;
    }

    struct ScheduleAlert {
        uint256 currentTime;
        uint256 nextScheduled;
        uint256 interval;
    }

    uint256 public lastTriggeredTime;

    constructor() {
        lastTriggeredTime = block.timestamp;
    }

    function collect() external view override returns (bytes memory) {
        return
            abi.encode(
                ScheduleData({
                    blockNumber: block.number,
                    timestamp: block.timestamp,
                    lastTrigger: lastTriggeredTime
                })
            );
    }

    function shouldRespond(
        bytes[] calldata data
    )
        external
        pure
        override
        returns (bool shouldTrigger, bytes memory responseData)
    {
        if (data.length == 0) {
            return (false, "");
        }

        ScheduleData memory schedule = abi.decode(data[0], (ScheduleData));

        // Check if enough time has passed since last trigger (using data from collect)
        if (schedule.timestamp >= schedule.lastTrigger + INTERVAL_SECONDS) {
            // Return data in the format expected by response_function:
            // executeScheduledAction(uint256,string)
            return (
                true,
                abi.encode(
                    schedule.timestamp, // current timestamp
                    "daily_maintenance" // action description
                )
            );
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function updateLastTrigger() external {
        lastTriggeredTime = block.timestamp;
    }

    // NOTE: For testing purposes only
    function getInterval() external pure returns (uint256) {
        return INTERVAL_SECONDS;
    }

    // NOTE: For testing purposes only
    function getNextTriggerTime() external view returns (uint256) {
        return lastTriggeredTime + INTERVAL_SECONDS;
    }

    // NOTE: For testing purposes only
    function timeUntilNext() external view returns (uint256) {
        uint256 nextTime = lastTriggeredTime + INTERVAL_SECONDS;
        if (block.timestamp >= nextTime) {
            return 0;
        }
        return nextTime - block.timestamp;
    }
}
