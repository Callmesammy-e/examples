// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {SimpleFeeChangeTrap} from "../src/SimpleFeeChangeTrap.sol";
import {FeeViolationResponse} from "../src/FeeViolationResponse.sol";

contract SimpleFeeChangeTrapTest is Test {
    SimpleFeeChangeTrap public trap;
    FeeViolationResponse public responseContract;
    
    address constant PROTOCOL1 = 0x742d35cC6634C0532925a3B8d80a6B24C5D06e41;
    address constant PROTOCOL2 = 0x8Ba1f109551Bd432803012645Aac136C40872A5F;
    address constant PROTOCOL3 = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
    address constant TEST_PROTOCOL = 0x1111111111111111111111111111111111111111;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    function setUp() public {
        trap = new SimpleFeeChangeTrap();
        responseContract = new FeeViolationResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        address[] memory protocols = trap.getMonitoredProtocols();
        uint256 maxFee = trap.getMaxFeeBps();
        
        assertEq(protocols.length, 3);
        assertEq(protocols[0], PROTOCOL1);
        assertEq(protocols[1], PROTOCOL2);
        assertEq(protocols[2], PROTOCOL3);
        assertEq(maxFee, 2000); // 20% in BPS
    }
    
    function test_CollectData() public {
        // Mock fee responses for all monitored protocols
        address[] memory protocols = trap.getMonitoredProtocols();
        for (uint256 i = 0; i < protocols.length; i++) {
            vm.mockCall(
                protocols[i],
                abi.encodeWithSignature("performanceFee()"),
                abi.encode(1000) // 10% fee
            );
        }
        
        bytes memory data = trap.collect();
        assertTrue(data.length > 0);
        
        SimpleFeeChangeTrap.FeeData[] memory fees = 
            abi.decode(data, (SimpleFeeChangeTrap.FeeData[]));
        assertEq(fees.length, 3);
    }
    
    function test_NoFeeViolation() public {
        // Mock normal fees for all protocols (below threshold)
        address[] memory protocols = trap.getMonitoredProtocols();
        for (uint256 i = 0; i < protocols.length; i++) {
            vm.mockCall(
                protocols[i],
                abi.encodeWithSignature("performanceFee()"),
                abi.encode(1000) // 10% fee (below 20% threshold)
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_FeeViolation() public {
        address[] memory protocols = trap.getMonitoredProtocols();
        
        // Mock high fee for first protocol
        vm.mockCall(
            protocols[0],
            abi.encodeWithSignature("performanceFee()"),
            abi.encode(2500) // 25% fee (above 20% threshold)
        );
        
        // Mock normal fees for others
        for (uint256 i = 1; i < protocols.length; i++) {
            vm.mockCall(
                protocols[i],
                abi.encodeWithSignature("performanceFee()"),
                abi.encode(1000) // 10% fee
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
        
        SimpleFeeChangeTrap.FeeAlert[] memory alerts = 
            abi.decode(responseData, (SimpleFeeChangeTrap.FeeAlert[]));
        
        assertEq(alerts.length, 1);
        assertEq(alerts[0].protocol, protocols[0]);
        assertEq(alerts[0].fee, 2500);
        assertEq(alerts[0].maxFee, 2000);
    }
    
    function test_FallbackFeeFunction() public {
        address[] memory protocols = trap.getMonitoredProtocols();
        
        // Mock performanceFee to fail, but fee() to succeed
        vm.mockCallRevert(
            protocols[0],
            abi.encodeWithSignature("performanceFee()"),
            "Function not found"
        );
        
        vm.mockCall(
            protocols[0],
            abi.encodeWithSignature("fee()"),
            abi.encode(1500) // 15% fee
        );
        
        // Mock normal fees for others
        for (uint256 i = 1; i < protocols.length; i++) {
            vm.mockCall(
                protocols[i],
                abi.encodeWithSignature("performanceFee()"),
                abi.encode(1000) // 10% fee
            );
        }
        
        bytes memory data = trap.collect();
        SimpleFeeChangeTrap.FeeData[] memory fees = 
            abi.decode(data, (SimpleFeeChangeTrap.FeeData[]));
        
        assertEq(fees[0].fee, 1500); // Should use fee() fallback
    }
    
    function test_AddProtocol() public {
        trap.addMonitoredProtocol(TEST_PROTOCOL);
        
        address[] memory protocols = trap.getMonitoredProtocols();
        assertEq(protocols.length, 4);
        assertEq(protocols[3], TEST_PROTOCOL);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        address[] memory protocols = trap.getMonitoredProtocols();
        
        // Mock high fee for first protocol (triggering violation)
        vm.mockCall(
            protocols[0],
            abi.encodeWithSignature("performanceFee()"),
            abi.encode(2500) // 25% fee (above 20% threshold)
        );
        
        // Mock normal fees for others
        for (uint256 i = 1; i < protocols.length; i++) {
            vm.mockCall(
                protocols[i],
                abi.encodeWithSignature("performanceFee()"),
                abi.encode(1000) // 10% fee
            );
        }
        
        // Collect data and get response from trap
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for excessive fee");
        
        // Verify we can decode the response data (just to check format)
        uint256 feeValue = abi.decode(responseData, (uint256));
        assertEq(feeValue, 2500, "Fee value should be 2500 BPS (25%)");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("handleViolation(uint256)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify violation was handled
        assertTrue(responseContract.wasViolationHandled(2500));
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.handleViolation(2500);
    }
}