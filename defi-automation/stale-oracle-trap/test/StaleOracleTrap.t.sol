// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StaleOracleTrap} from "../src/StaleOracleTrap.sol";
import {StaleOracleResponse} from "../src/StaleOracleResponse.sol";

contract StaleOracleTrapTest is Test {
    StaleOracleTrap public trap;
    StaleOracleResponse public responseContract;
    
    address constant ETH_USD_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant BTC_USD_ORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address constant USDC_USD_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    uint256 constant MAX_STALENESS = 3600; // 1 hour
    
    function setUp() public {
        trap = new StaleOracleTrap();
        responseContract = new StaleOracleResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        address[] memory oracles = trap.getMonitoredOracles();
        uint256 staleness = trap.getMaxStaleness();
        
        assertEq(oracles.length, 3);
        assertEq(oracles[0], ETH_USD_ORACLE);
        assertEq(oracles[1], BTC_USD_ORACLE);  
        assertEq(oracles[2], USDC_USD_ORACLE);
        assertEq(staleness, MAX_STALENESS);
    }
    
    function test_CollectData() public {
        // Mock oracle responses for all monitored oracles
        address[] memory oracles = trap.getMonitoredOracles();
        for (uint256 i = 0; i < oracles.length; i++) {
            vm.mockCall(
                oracles[i],
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(
                    uint80(1),           // roundId
                    int256(2000e8),      // price
                    block.timestamp,     // startedAt
                    block.timestamp,     // updatedAt (fresh)
                    uint80(1)            // answeredInRound
                )
            );
        }
        
        bytes memory data = trap.collect();
        assertTrue(data.length > 0);
        
        StaleOracleTrap.OracleData[] memory oracleData = 
            abi.decode(data, (StaleOracleTrap.OracleData[]));
        assertEq(oracleData.length, 3);
    }
    
    function test_NoStaleOracles() public {
        // Mock fresh oracle responses
        address[] memory oracles = trap.getMonitoredOracles();
        for (uint256 i = 0; i < oracles.length; i++) {
            vm.mockCall(
                oracles[i],
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(
                    uint80(1),           // roundId
                    int256(2000e8),      // price
                    block.timestamp,     // startedAt
                    block.timestamp,     // updatedAt (fresh)
                    uint80(1)            // answeredInRound
                )
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_StaleOracle() public {
        // Warp time forward to ensure we have valid timestamps
        vm.warp(block.timestamp + 10000);
        
        address[] memory oracles = trap.getMonitoredOracles();
        
        // Mock stale oracle for first oracle
        vm.mockCall(
            oracles[0],
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1),                      // roundId
                int256(2000e8),                 // price
                block.timestamp - 8000,         // startedAt
                block.timestamp - 7200,         // updatedAt (2 hours ago - stale)
                uint80(1)                       // answeredInRound
            )
        );
        
        // Mock fresh oracles for others
        for (uint256 i = 1; i < oracles.length; i++) {
            vm.mockCall(
                oracles[i],
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(
                    uint80(1),           // roundId
                    int256(2000e8),      // price
                    block.timestamp - 100,     // startedAt
                    block.timestamp - 100,     // updatedAt (fresh)
                    uint80(1)            // answeredInRound
                )
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_AddOracle() public {
        address newOracle = 0x1111111111111111111111111111111111111111;
        trap.addMonitoredOracle(newOracle);
        
        address[] memory oracles = trap.getMonitoredOracles();
        assertEq(oracles.length, 4);
        assertEq(oracles[3], newOracle);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Warp time forward to ensure we have valid timestamps
        vm.warp(block.timestamp + 10000);
        
        address[] memory oracles = trap.getMonitoredOracles();
        
        // Mock stale oracle for first oracle
        vm.mockCall(
            oracles[0],
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1),                      // roundId
                int256(2000e8),                 // price
                block.timestamp - 8000,         // startedAt
                block.timestamp - 7200,         // updatedAt (2 hours ago - stale)
                uint80(1)                       // answeredInRound
            )
        );
        
        // Mock fresh oracles for others
        for (uint256 i = 1; i < oracles.length; i++) {
            vm.mockCall(
                oracles[i],
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(
                    uint80(1),                  // roundId
                    int256(2000e8),             // price
                    block.timestamp - 100,      // startedAt
                    block.timestamp - 100,      // updatedAt (fresh)
                    uint80(1)                   // answeredInRound
                )
            );
        }
        
        // Collect data and get response from trap
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for stale oracle");
        
        // Verify we can decode the response data (just to check format)
        (address oracle,,, uint256 staleness) = 
            abi.decode(responseData, (address, int256, uint256, uint256));
        assertEq(oracle, oracles[0], "Alert should be for first oracle");
        assertEq(staleness, 7200, "Staleness should be 2 hours");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("alertStaleOracle(address,int256,uint256,uint256)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");
        
        // Verify alert was handled
        assertTrue(responseContract.wasOracleAlerted(oracles[0]));
    }
}