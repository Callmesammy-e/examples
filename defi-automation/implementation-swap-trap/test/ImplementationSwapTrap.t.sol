// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ImplementationSwapTrap} from "../src/ImplementationSwapTrap.sol";
import {ImplementationSwapResponse} from "../src/ImplementationSwapResponse.sol";

contract ImplementationSwapTrapTest is Test {
    ImplementationSwapTrap public trap;
    ImplementationSwapResponse public responseContract;
    
    address constant UNISWAP_PROXY = 0xEe6A57eC80ea46401049E92587E52f5Ec1c24785;
    address constant COMPOUND_PROXY = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address constant AAVE_PROXY = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    
    address constant TEST_PROXY = 0x1111111111111111111111111111111111111111;
    address constant OLD_OWNER = 0x2222222222222222222222222222222222222222;
    address constant NEW_OWNER = 0x3333333333333333333333333333333333333333;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    function setUp() public {
        trap = new ImplementationSwapTrap();
        responseContract = new ImplementationSwapResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        assertEq(proxies.length, 3);
        assertEq(proxies[0].proxy, UNISWAP_PROXY);
        assertEq(proxies[1].proxy, COMPOUND_PROXY);
        assertEq(proxies[2].proxy, AAVE_PROXY);
    }
    
    function test_CollectData() public {
        // Mock owner/admin responses for all monitored proxies
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i].hasOwner) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("owner()"),
                    abi.encode(OLD_OWNER)
                );
            }
            if (proxies[i].hasAdmin) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("admin()"),
                    abi.encode(OLD_OWNER)
                );
            }
        }
        
        bytes memory data = trap.collect();
        assertTrue(data.length > 0);
        
        ImplementationSwapTrap.ProxyState[] memory states = 
            abi.decode(data, (ImplementationSwapTrap.ProxyState[]));
        assertEq(states.length, 3);
    }
    
    function test_NoChanges() public {
        // Mock stable owner/admin for all proxies
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i].hasOwner) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("owner()"),
                    abi.encode(OLD_OWNER)
                );
            }
            if (proxies[i].hasAdmin) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("admin()"),
                    abi.encode(OLD_OWNER)
                );
            }
        }
        
        bytes memory data1 = trap.collect();
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger);
    }
    
    function test_OwnerChange() public {
        // Mock existing proxies first
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i].hasOwner) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("owner()"),
                    abi.encode(OLD_OWNER)
                );
            }
            if (proxies[i].hasAdmin) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("admin()"),
                    abi.encode(OLD_OWNER)
                );
            }
        }
        
        // Add test proxy and mock initial owner
        trap.addMonitoredProxy(TEST_PROXY, true, false);
        
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("owner()"),
            abi.encode(OLD_OWNER)
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock owner change
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("owner()"),
            abi.encode(NEW_OWNER)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_AdminChange() public {
        // Mock existing proxies first
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i].hasOwner) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("owner()"),
                    abi.encode(OLD_OWNER)
                );
            }
            if (proxies[i].hasAdmin) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("admin()"),
                    abi.encode(OLD_OWNER)
                );
            }
        }
        
        // Add test proxy with admin monitoring
        trap.addMonitoredProxy(TEST_PROXY, false, true);
        
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("admin()"),
            abi.encode(OLD_OWNER)
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock admin change
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("admin()"),
            abi.encode(NEW_OWNER)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_AddProxy() public {
        trap.addMonitoredProxy(TEST_PROXY, true, false);
        
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        assertEq(proxies.length, 4);
        assertEq(proxies[3].proxy, TEST_PROXY);
        assertTrue(proxies[3].hasOwner);
        assertFalse(proxies[3].hasAdmin);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Mock existing proxies first
        ImplementationSwapTrap.ProxyInfo[] memory proxies = trap.getMonitoredProxies();
        for (uint256 i = 0; i < proxies.length; i++) {
            if (proxies[i].hasOwner) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("owner()"),
                    abi.encode(OLD_OWNER)
                );
            }
            if (proxies[i].hasAdmin) {
                vm.mockCall(
                    proxies[i].proxy,
                    abi.encodeWithSignature("admin()"),
                    abi.encode(OLD_OWNER)
                );
            }
        }
        
        // Add test proxy and mock initial owner
        trap.addMonitoredProxy(TEST_PROXY, true, false);
        
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("owner()"),
            abi.encode(OLD_OWNER)
        );
        
        bytes memory data1 = trap.collect();
        
        // Mock owner change
        vm.mockCall(
            TEST_PROXY,
            abi.encodeWithSignature("owner()"),
            abi.encode(NEW_OWNER)
        );
        
        bytes memory data2 = trap.collect();
        
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2;
        dataArray[1] = data1;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for owner change");
        
        // Verify we can decode the response data (just to check format)
        (address proxy, address oldImpl, address newImpl, string memory changeType) = 
            abi.decode(responseData, (address, address, address, string));
        assertEq(proxy, TEST_PROXY, "Proxy should be test proxy");
        assertEq(newImpl, NEW_OWNER, "New implementation should be new owner");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("handleProxyUpgrade(address,address,address,string)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify upgrade was handled
        assertTrue(responseContract.wasUpgradeHandled(TEST_PROXY));
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.handleProxyUpgrade(TEST_PROXY, address(0), address(0), "test");
    }
}