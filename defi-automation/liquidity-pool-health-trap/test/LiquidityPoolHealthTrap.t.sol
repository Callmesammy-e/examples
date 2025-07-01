// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {LiquidityPoolHealthTrap} from "../src/LiquidityPoolHealthTrap.sol";
import {LiquidityPoolHealthResponse} from "../src/LiquidityPoolHealthResponse.sol";

contract LiquidityPoolHealthTrapTest is Test {
    LiquidityPoolHealthTrap public trap;
    LiquidityPoolHealthResponse public responseContract;
    
    // Real pool addresses from contract
    address constant USDC_ETH_POOL = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address constant USDT_ETH_POOL = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address constant DAI_ETH_POOL = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address constant MOCK_TRAP_CONFIG = 0x7E1b5cA35bd6BcAe8Ff33C0dDf79EffCFf0Ad19e;
    
    // WETH address
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Thresholds
    uint256 constant MIN_LIQUIDITY_USD = 1000000e18;  // $1M
    uint256 constant MAX_PRICE_DEVIATION_BPS = 500;   // 5%
    
    function setUp() public {
        trap = new LiquidityPoolHealthTrap();
        responseContract = new LiquidityPoolHealthResponse(MOCK_TRAP_CONFIG);
    }
    
    function _mockPoolData(
        address pool,
        address token0,
        address token1,
        uint112 reserve0,
        uint112 reserve1,
        uint8 decimals0,
        uint8 decimals1
    ) internal {
        // Mock getReserves()
        vm.mockCall(
            pool,
            abi.encodeWithSignature("getReserves()"),
            abi.encode(reserve0, reserve1, uint32(block.timestamp))
        );
        
        // Mock token0() and token1()
        vm.mockCall(
            pool,
            abi.encodeWithSignature("token0()"),
            abi.encode(token0)
        );
        
        vm.mockCall(
            pool,
            abi.encodeWithSignature("token1()"),
            abi.encode(token1)
        );
        
        // Mock token decimals
        vm.mockCall(
            token0,
            abi.encodeWithSignature("decimals()"),
            abi.encode(decimals0)
        );
        
        vm.mockCall(
            token1,
            abi.encodeWithSignature("decimals()"),
            abi.encode(decimals1)
        );
    }
    
    function _mockHealthyPools() internal {
        // Mock USDC/ETH pool - healthy
        _mockPoolData(
            USDC_ETH_POOL,
            0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
            WETH,
            2000000e6,  // 2M USDC
            1000e18,    // 1000 ETH
            6,  // USDC decimals
            18  // WETH decimals
        );
        
        // Mock USDT/ETH pool - healthy
        _mockPoolData(
            USDT_ETH_POOL,
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            WETH,
            1800000e6,  // 1.8M USDT
            900e18,     // 900 ETH
            6,  // USDT decimals
            18  // WETH decimals
        );
        
        // Mock DAI/ETH pool - healthy
        _mockPoolData(
            DAI_ETH_POOL,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            WETH,
            1600000e18, // 1.6M DAI
            800e18,     // 800 ETH
            18, // DAI decimals
            18  // WETH decimals
        );
    }
    
    function _mockUnhealthyPool(address pool) internal {
        // Mock pool with very low liquidity (unhealthy)
        _mockPoolData(
            pool,
            0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
            WETH,
            100e6,      // Only 100 USDC (very low)
            0.05e18,    // Only 0.05 ETH (very low)
            6,  // USDC decimals
            18  // WETH decimals
        );
    }
    
    function test_InitialState() public view {
        address[] memory pools = trap.getMonitoredPools();
        uint256 minThreshold = trap.getMinThreshold();
        
        assertEq(pools.length, 3);
        assertEq(pools[0], USDC_ETH_POOL);
        assertEq(pools[1], USDT_ETH_POOL);
        assertEq(pools[2], DAI_ETH_POOL);
        
        assertEq(minThreshold, 1000000e6);
    }
    
    function test_CollectHealthyPools() public {
        _mockHealthyPools();
        
        bytes memory data = trap.collect();
        
        // Verify we got data (non-empty)
        assertTrue(data.length > 0);
    }
    
    function test_AllPoolsHealthy() public {
        _mockHealthyPools();
        
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertFalse(shouldTrigger);
        assertEq(responseData.length, 0);
    }
    
    function test_SinglePoolUnhealthy() public {
        _mockHealthyPools();
        
        // Override one pool to be unhealthy
        _mockUnhealthyPool(USDC_ETH_POOL);
        
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_PoolUnhealthy() public {
        // Make one pool unhealthy (low reserves)
        _mockPoolData(
            USDC_ETH_POOL,
            0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
            WETH,
            100e6,      // Only 100 USDC (very low)
            0.05e18,    // Only 0.05 ETH (very low)
            6,  // USDC decimals
            18  // WETH decimals
        );
        
        // Mock other pools as healthy
        _mockPoolData(
            USDT_ETH_POOL,
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            WETH,
            1800000e6,  // 1.8M USDT
            900e18,     // 900 ETH
            6,  // USDT decimals
            18  // WETH decimals
        );
        
        _mockPoolData(
            DAI_ETH_POOL,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            WETH,
            1600000e18, // 1.6M DAI
            800e18,     // 800 ETH
            18, // DAI decimals
            18  // WETH decimals
        );
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_AddPool() public {
        address newPool = 0x1111111111111111111111111111111111111111;
        trap.addMonitoredPool(newPool);
        
        address[] memory pools = trap.getMonitoredPools();
        assertEq(pools.length, 4);
        assertEq(pools[3], newPool);
    }
    
    function test_EmptyDataArray() public view {
        bytes[] memory emptyArray = new bytes[](0);
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(emptyArray);
        
        assertFalse(shouldTrigger);
        assertEq(responseData.length, 0);
    }
    
    function test_ZeroReserves() public {
        // Mock pool with zero reserves (extremely unhealthy)
        _mockPoolData(
            USDC_ETH_POOL,
            0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
            WETH,
            0,  // Zero reserves
            0,  // Zero reserves
            6,  // USDC decimals
            18  // WETH decimals
        );
        
        // Mock other pools as healthy
        _mockPoolData(
            USDT_ETH_POOL,
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            WETH,
            1800000e6,  // 1.8M USDT
            900e18,     // 900 ETH
            6,  // USDT decimals
            18  // WETH decimals
        );
        
        _mockPoolData(
            DAI_ETH_POOL,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            WETH,
            1600000e18, // 1.6M DAI
            800e18,     // 800 ETH
            18, // DAI decimals
            18  // WETH decimals
        );
        
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_ConstantBehavior() public {
        // Test that multiple deployments behave consistently
        LiquidityPoolHealthTrap trap2 = new LiquidityPoolHealthTrap();
        
        address[] memory pools1 = trap.getMonitoredPools();
        address[] memory pools2 = trap2.getMonitoredPools();
        
        assertEq(pools1.length, pools2.length);
        for (uint256 i = 0; i < pools1.length; i++) {
            assertEq(pools1[i], pools2[i]);
        }
        
        uint256 threshold1 = trap.getMinThreshold();
        uint256 threshold2 = trap2.getMinThreshold();
        
        assertEq(threshold1, threshold2);
    }
    
    function test_MultiplePoolsUnhealthy() public {
        // Make all pools unhealthy
        _mockUnhealthyPool(USDC_ETH_POOL);
        _mockUnhealthyPool(USDT_ETH_POOL);
        _mockUnhealthyPool(DAI_ETH_POOL);
        
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        
        assertTrue(shouldTrigger);
        assertTrue(responseData.length > 0);
    }
    
    function test_ReserveThreshold() public {
        // Mock all pools with healthy reserves
        _mockHealthyPools();
        
        bytes memory collectData = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = collectData;
        
        (bool shouldTrigger,) = trap.shouldRespond(dataArray);
        assertFalse(shouldTrigger); // Should not trigger with healthy reserves
    }

    // Test response contract integration using actual shouldRespond data
    function test_ResponseContractWithTrapData() public {
        // Make first pool unhealthy
        _mockPoolData(
            USDC_ETH_POOL,
            0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
            WETH,
            100e6,      // Only 100 USDC (very low - below threshold)
            0.05e18,    // Only 0.05 ETH (very low)
            6,  // USDC decimals
            18  // WETH decimals
        );
        
        // Mock other pools as healthy
        _mockPoolData(
            USDT_ETH_POOL,
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            WETH,
            1800000e6,  // 1.8M USDT (healthy)
            900e18,     // 900 ETH
            6,  // USDT decimals
            18  // WETH decimals
        );
        
        _mockPoolData(
            DAI_ETH_POOL,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            WETH,
            1600000e18, // 1.6M DAI (healthy)
            800e18,     // 800 ETH
            18, // DAI decimals
            18  // WETH decimals
        );
        
        bytes memory data = trap.collect();
        bytes[] memory dataArray = new bytes[](1);
        dataArray[0] = data;
        
        (bool shouldTrigger, bytes memory responseData) = trap.shouldRespond(dataArray);
        assertTrue(shouldTrigger, "Trap should trigger for unhealthy pool");
        
        // Verify we can decode the response data (just to check format)
        LiquidityPoolHealthResponse.PoolHealthAlert[] memory alerts = 
            abi.decode(responseData, (LiquidityPoolHealthResponse.PoolHealthAlert[]));
        assertEq(alerts.length, 1, "Should have one pool health alert");
        assertEq(alerts[0].pool, USDC_ETH_POOL, "Alert should be for USDC/ETH pool");
        assertEq(alerts[0].reserve0, 100e6, "Reserve0 should be 100 USDC");
        assertEq(alerts[0].reserve1, 0.05e18, "Reserve1 should be 0.05 ETH");
        assertFalse(alerts[0].isHealthy, "Pool should be marked as unhealthy");
        
        // This is how the Drosera operator would call the response contract:
        // It combines the function selector with the response data from shouldRespond
        vm.prank(MOCK_TRAP_CONFIG);
        (bool success,) = address(responseContract).call(
            abi.encodePacked(
                bytes4(keccak256("handleUnhealthyPools((address,address,address,uint112,uint112,uint256,uint256,bool)[])")),
                responseData
            )
        );
        assertTrue(success, "Response contract call should succeed");

        // Verify pool health was handled
        assertTrue(responseContract.wasPoolHealthHandled(USDC_ETH_POOL));
    }

    function test_ResponseContractAccessControl() public {
        // Test that only TrapConfig can call response functions
        LiquidityPoolHealthResponse.PoolHealthAlert[] memory alerts = new LiquidityPoolHealthResponse.PoolHealthAlert[](1);
        alerts[0] = LiquidityPoolHealthResponse.PoolHealthAlert({
            pool: USDC_ETH_POOL,
            token0: address(0),
            token1: address(0),
            reserve0: 100e6,
            reserve1: 0.05e18,
            minThreshold: 1000000e6,
            currentRatio: 0,
            isHealthy: false
        });
        
        vm.expectRevert("Only TrapConfig can call this");
        responseContract.handleUnhealthyPools(alerts);
    }
}