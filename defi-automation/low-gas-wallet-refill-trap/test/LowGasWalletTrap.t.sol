// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {LowGasWalletTrap} from "../src/LowGasWalletTrap.sol";
import {LowGasWalletResponse} from "../src/LowGasWalletResponse.sol";

contract LowGasWalletTrapTest is Test {
    LowGasWalletTrap public trap;
    LowGasWalletResponse public responseContract;
    
    uint256 constant MIN_BALANCE = 0.1 ether;
    uint256 constant REFILL_AMOUNT = 0.5 ether;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    address constant TEST_WALLET = 0x1111111111111111111111111111111111111111;
    
    function setUp() public {
        trap = new LowGasWalletTrap();
        responseContract = new LowGasWalletResponse(MOCK_TRAP_CONFIG);
    }
    
    function test_InitialState() public view {
        address[] memory wallets = trap.getMonitoredWallets();
        assertEq(wallets.length, 3);
        assertEq(trap.getMinBalance(), MIN_BALANCE);
        assertEq(trap.getRefillAmount(), REFILL_AMOUNT);
    }
    
    function test_CollectBalance() public {
        bytes memory data = trap.collect();
        LowGasWalletTrap.WalletBalance[] memory balances = 
            abi.decode(data, (LowGasWalletTrap.WalletBalance[]));
        
        assertEq(balances.length, 3);
        assertTrue(balances[0].wallet != address(0));
    }
    
    function test_BelowThreshold() public {
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        // Wallets may or may not be below threshold depending on their actual balances
        if (shouldTrigger) {
            assertTrue(responseData.length > 0);
        }
    }
    
    function test_AddWallet() public {
        trap.addMonitoredWallet(TEST_WALLET);
        
        address[] memory wallets = trap.getMonitoredWallets();
        assertEq(wallets.length, 4);
        assertEq(wallets[3], TEST_WALLET);
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Add a test wallet and set its balance to be below threshold
        trap.addMonitoredWallet(TEST_WALLET);
        vm.deal(TEST_WALLET, 0.05 ether); // Below MIN_BALANCE of 0.1 ether
        
        // Collect data and get response from trap
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for low balance");
        
        // Verify we can decode the response data (just to check format)
        (address wallet, uint256 amount) = 
            abi.decode(responseData, (address, uint256));
        assertEq(wallet, TEST_WALLET, "Wallet should be test wallet");
        assertEq(amount, REFILL_AMOUNT, "Amount should be refill amount");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("refillWallet(address,uint256)")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify refill was handled
        assertTrue(responseContract.wasWalletRefilled(TEST_WALLET));
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.refillWallet(TEST_WALLET, REFILL_AMOUNT);
    }
}