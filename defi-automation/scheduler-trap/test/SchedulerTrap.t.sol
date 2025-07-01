// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {SchedulerTrap} from "../src/SchedulerTrap.sol";
import {SchedulerResponse} from "../src/SchedulerResponse.sol";

contract SchedulerTrapTest is Test {
    SchedulerTrap public trap;
    SchedulerResponse public responseContract;
    
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    function setUp() public {
        trap = new SchedulerTrap();
        responseContract = new SchedulerResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        assertEq(trap.getInterval(), 86400); // 24 hours in seconds
        assertTrue(trap.getNextTriggerTime() > 0);
    }
    
    function test_CollectData() public {
        bytes memory data = trap.collect();
        SchedulerTrap.ScheduleData memory schedule = 
            abi.decode(data, (SchedulerTrap.ScheduleData));
        
        assertEq(schedule.blockNumber, block.number);
        assertEq(schedule.timestamp, block.timestamp);
        assertTrue(schedule.lastTrigger > 0);
    }
    
    function test_TimeUntilNext() public view {
        uint256 timeLeft = trap.timeUntilNext();
        assertTrue(timeLeft <= 86400); // Should be within 24 hours
    }
    
    function test_UpdateTrigger() public {
        uint256 oldTime = trap.getNextTriggerTime();
        
        // Skip forward in time to simulate trigger
        vm.warp(block.timestamp + 86401); // Move forward 24 hours + 1 second
        
        trap.updateLastTrigger();
        uint256 newTime = trap.getNextTriggerTime();
        
        assertTrue(newTime > oldTime);
    }

    function test_ScheduledTrigger() public {
        // Skip forward 24 hours to trigger the scheduler
        vm.warp(block.timestamp + 86401);
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger after 24 hours");
        assertTrue(responseData.length > 0);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Skip forward 24 hours to trigger the scheduler
        vm.warp(block.timestamp + 86401);
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger after 24 hours");
        
        // Verify we can decode the response data (just to check format)
        (uint256 timestamp, string memory action) = 
            abi.decode(responseData, (uint256, string));
        assertTrue(timestamp > 0, "Timestamp should be valid");
        assertEq(action, "daily_maintenance", "Action should be daily_maintenance");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("executeScheduledAction(uint256,string)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify action was executed
        assertTrue(responseContract.wasActionExecuted("daily_maintenance"));
        assertEq(responseContract.getActionExecutionTime("daily_maintenance"), timestamp);
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.executeScheduledAction(block.timestamp, "test");
    }
}