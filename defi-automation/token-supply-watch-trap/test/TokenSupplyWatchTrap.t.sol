// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {TokenSupplyWatchTrap} from "../src/TokenSupplyWatchTrap.sol";
import {TokenSupplyWatchResponse} from "../src/TokenSupplyWatchResponse.sol";

contract TokenSupplyWatchTrapTest is Test {
    TokenSupplyWatchTrap public trap;
    TokenSupplyWatchResponse public responseContract;
    
    address constant USDC_TOKEN = 0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D;
    address constant USDT_TOKEN = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant TEST_TOKEN = 0x1111111111111111111111111111111111111111;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    function setUp() public {
        trap = new TokenSupplyWatchTrap();
        responseContract = new TokenSupplyWatchResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        address[] memory tokens = trap.getMonitoredTokens();
        uint256 threshold = trap.getChangeThreshold();
        
        assertEq(tokens.length, 3);
        assertEq(tokens[0], USDC_TOKEN);
        assertEq(tokens[1], USDT_TOKEN);
        assertEq(tokens[2], DAI_TOKEN);
        assertEq(threshold, 500); // 5% in BPS
    }
    
    function test_CollectData() public {
        // Mock token supplies for all monitored tokens
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens
            );
        }
        
        bytes memory data = trap.collect();
        assertTrue(data.length > 0);
        
        TokenSupplyWatchTrap.SupplyData[] memory supplies = 
            abi.decode(data, (TokenSupplyWatchTrap.SupplyData[]));
        assertEq(supplies.length, 3);
    }
    
    function test_NoSupplyChanges() public {
        // Mock stable supplies for all tokens
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        bytes memory data1 = trap.collect();
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_SupplyIncrease() public {
        // Mock existing tokens first
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        // Add test token
        trap.addMonitoredToken(TEST_TOKEN);
        
        // Mock initial supply for test token
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(100000000e6) // 100M tokens
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock supply increase (10% increase)
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(110000000e6) // 110M tokens
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_SupplyDecrease() public {
        // Mock existing tokens first
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        // Add test token
        trap.addMonitoredToken(TEST_TOKEN);
        
        // Mock initial supply
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(100000000e6)
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock supply decrease (8% decrease)
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(92000000e6)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_SmallChangeIgnored() public {
        // Mock existing tokens first
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        // Add test token
        trap.addMonitoredToken(TEST_TOKEN);
        
        // Mock initial supply
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(100000000e6)
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock small supply change (2% increase - below 5% threshold)
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(102000000e6)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_SmallAbsoluteChangeIgnored() public {
        // Mock existing tokens first  
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        // Add test token
        trap.addMonitoredToken(TEST_TOKEN);
        
        // Mock initial supply (small supply)
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(1000000e6) // 1M tokens
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock large percentage but small absolute change
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(1100000e6) // 1.1M tokens (10% but only 100k change)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger); // Should not trigger due to small absolute change
    }
    
    function test_AddToken() public {
        trap.addMonitoredToken(TEST_TOKEN);
        
        address[] memory tokens = trap.getMonitoredTokens();
        assertEq(tokens.length, 4);
        assertEq(tokens[3], TEST_TOKEN);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Mock existing tokens first
        address[] memory tokens = trap.getMonitoredTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.mockCall(
                tokens[i],
                abi.encodeWithSignature("totalSupply()"),
                abi.encode(1000000000e6) // 1B tokens (stable)
            );
        }
        
        // Add test token
        trap.addMonitoredToken(TEST_TOKEN);
        
        // Mock initial supply for test token
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(100000000e6) // 100M tokens
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock supply increase (10% increase)
        vm.mockCall(
            TEST_TOKEN,
            abi.encodeWithSignature("totalSupply()"),
            abi.encode(110000000e6) // 110M tokens
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for significant supply change");
        
        // Verify we can decode the response data (just to check format)
        TokenSupplyWatchResponse.SupplyAlert[] memory alerts = 
            abi.decode(responseData, (TokenSupplyWatchResponse.SupplyAlert[]));
        assertEq(alerts.length, 1, "Should have one supply alert");
        assertEq(alerts[0].token, TEST_TOKEN, "Alert should be for test token");
        assertEq(alerts[0].oldSupply, 100000000e6, "Old supply should be 100M");
        assertEq(alerts[0].newSupply, 110000000e6, "New supply should be 110M");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("handleSuspiciousSupplyChange((address,uint256,uint256)[])")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify supply change was handled
        assertTrue(responseContract.wasSupplyChangeHandled(TEST_TOKEN));
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        TokenSupplyWatchResponse.SupplyAlert[] memory alerts = new TokenSupplyWatchResponse.SupplyAlert[](1);
        alerts[0] = TokenSupplyWatchResponse.SupplyAlert({
            token: TEST_TOKEN,
            oldSupply: 100000000e6,
            newSupply: 110000000e6
        });
        
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.handleSuspiciousSupplyChange(alerts);
    }
}