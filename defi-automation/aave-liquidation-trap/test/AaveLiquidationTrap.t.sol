// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AaveLiquidationTrap} from "../src/AaveLiquidationTrap.sol";
import {AaveLiquidationResponse} from "../src/AaveLiquidationResponse.sol";

contract AaveLiquidationTrapTest is Test {
    AaveLiquidationTrap public trap;
    AaveLiquidationResponse public responseContract;
    
    address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant TEST_USER = 0x1111111111111111111111111111111111111111;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    function setUp() public {
        trap = new AaveLiquidationTrap();
        responseContract = new AaveLiquidationResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        address[] memory users = trap.getMonitoredUsers();
        uint256 threshold = trap.getLiquidationThreshold();
        
        assertEq(users.length, 1);
        assertEq(threshold, 1.05e18);
    }
    
    function test_CollectData() public {
        // Mock AAVE pool responses for all monitored users
        address[] memory users = trap.getMonitoredUsers();
        for (uint256 i = 0; i < users.length; i++) {
            vm.mockCall(
                AAVE_V3_POOL,
                abi.encodeWithSignature("getUserAccountData(address)", users[i]),
                abi.encode(
                    1000000e8, // collateral
                    500000e8,  // debt
                    400000e8,  // available borrows
                    8000,      // liquidation threshold
                    7000,      // ltv
                    2.0e18     // health factor (healthy)
                )
            );
        }
        
        bytes memory data = trap.collect();
        assertTrue(data.length > 0);
        
        AaveLiquidationTrap.UserPosition[] memory positions = 
            abi.decode(data, (AaveLiquidationTrap.UserPosition[]));
        assertEq(positions.length, 1);
    }
    
    function test_NoLiquidationRisk() public {
        // Mock healthy positions
        address[] memory users = trap.getMonitoredUsers();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            vm.mockCall(
                AAVE_V3_POOL,
                abi.encodeWithSignature("getUserAccountData(address)", user),
                abi.encode(
                    1000000e8, // collateral
                    100000e8,  // debt
                    500000e8,  // available borrows
                    8000,      // liquidation threshold
                    7000,      // ltv
                    2.5e18     // health factor (healthy)
                )
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_LiquidationRisk() public {
        address[] memory users = trap.getMonitoredUsers();
        
        // Mock risky position for first user
        vm.mockCall(
            AAVE_V3_POOL,
            abi.encodeWithSignature("getUserAccountData(address)", users[0]),
            abi.encode(
                1000000e8, // collateral
                800000e8,  // debt
                50000e8,   // available borrows
                8000,      // liquidation threshold
                7000,      // ltv
                1.02e18    // health factor (risky)
            )
        );
        
        // Mock healthy positions for others
        for (uint256 i = 1; i < users.length; i++) {
            vm.mockCall(
                AAVE_V3_POOL,
                abi.encodeWithSignature("getUserAccountData(address)", users[i]),
                abi.encode(
                    1000000e8, // collateral
                    100000e8,  // debt
                    500000e8,  // available borrows
                    8000,      // liquidation threshold
                    7000,      // ltv
                    2.5e18     // health factor (healthy)
                )
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        
        AaveLiquidationTrap.LiquidationAlert[] memory alerts = 
            abi.decode(responseData, (AaveLiquidationTrap.LiquidationAlert[]));
        
        assertEq(alerts.length, 1);
        assertEq(alerts[0].user, users[0]);
        assertEq(alerts[0].healthFactor, 1.02e18);
    }
    
    function test_AddUser() public {
        trap.addMonitoredUser(TEST_USER);
        
        address[] memory users = trap.getMonitoredUsers();
        assertEq(users.length, 2);
        assertEq(users[1], TEST_USER);
    }
    
    function test_NoDebtIgnored() public {
        address[] memory users = trap.getMonitoredUsers();
        
        // Mock position with low health factor but no debt for first user
        vm.mockCall(
            AAVE_V3_POOL,
            abi.encodeWithSignature("getUserAccountData(address)", users[0]),
            abi.encode(
                1000000e8, // collateral
                0,         // no debt
                1000000e8, // available borrows
                8000,      // liquidation threshold
                7000,      // ltv
                1.02e18    // low health factor
            )
        );
        
        // Mock healthy positions for other users
        for (uint256 i = 1; i < users.length; i++) {
            vm.mockCall(
                AAVE_V3_POOL,
                abi.encodeWithSignature("getUserAccountData(address)", users[i]),
                abi.encode(
                    1000000e8, // collateral
                    500000e8,  // debt
                    400000e8,  // available borrows
                    8000,      // liquidation threshold
                    7000,      // ltv
                    2.0e18     // health factor (healthy)
                )
            );
        }
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger); // Should not trigger without debt
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.liquidatePosition(TEST_USER, address(0), address(0), 0);
    }

    function test_ResponseContractWithTrapData() public {
        address[] memory users = trap.getMonitoredUsers();
        
        // Mock risky position for first user (triggering liquidation)
        vm.mockCall(
            AAVE_V3_POOL,
            abi.encodeWithSignature("getUserAccountData(address)", users[0]),
            abi.encode(
                1000000e8, // collateral
                900000e8,  // debt  
                10000e8,   // available borrows
                8000,      // liquidation threshold
                7000,      // ltv
                1.01e18    // health factor (very risky - below 1.05 threshold)
            )
        );
        
        // Collect data and get response from trap
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for risky position");
        
        // Verify we can decode the response data (just to check format)
        (address user, address collateralAsset, address debtAsset, uint256 debtAmount) = 
            abi.decode(responseData, (address, address, address, uint256));
        assertEq(user, users[0], "User should be first monitored user");
        assertEq(debtAmount, 900000e8, "Debt amount should match");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("liquidatePosition(address,address,address,uint256)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify liquidation was handled
        assertTrue(responseContract.wasLiquidationTriggered(users[0]));
    }

}