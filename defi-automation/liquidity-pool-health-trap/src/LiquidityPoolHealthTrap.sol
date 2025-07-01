// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/**
 * @title LiquidityPoolHealthTrap
 * @notice Monitor Uniswap V2 liquidity pool reserves
 * @dev Simple trap that detects when pool reserves drop below minimum thresholds
 */
contract LiquidityPoolHealthTrap is ITrap {
    uint256 constant MIN_RESERVE_THRESHOLD = 1000000e6; // 1M units minimum

    struct PoolReserves {
        address pool;
        uint112 reserve0;
        uint112 reserve1;
        uint256 blockNumber;
    }

    struct PoolAlert {
        address pool;
        uint112 reserve0;
        uint112 reserve1;
        uint256 minThreshold;
    }

    struct PoolHealthAlert {
        address pool;
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint256 minThreshold;
        uint256 currentRatio;
        bool isHealthy;
    }

    address[] public monitoredPools;

    constructor() {
        // Monitor major Uniswap V2 pools
        monitoredPools.push(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc); // USDC/WETH
        monitoredPools.push(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852); // USDT/WETH
        monitoredPools.push(0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11); // DAI/WETH
    }

    function collect() external view override returns (bytes memory) {
        PoolReserves[] memory reserves = new PoolReserves[](
            monitoredPools.length
        );

        for (uint256 i = 0; i < monitoredPools.length; i++) {
            address pool = monitoredPools[i];

            uint112 reserve0 = 0;
            uint112 reserve1 = 0;

            try IUniswapV2Pair(pool).getReserves() returns (
                uint112 _reserve0,
                uint112 _reserve1,
                uint32
            ) {
                reserve0 = _reserve0;
                reserve1 = _reserve1;
            } catch {}

            reserves[i] = PoolReserves({
                pool: pool,
                reserve0: reserve0,
                reserve1: reserve1,
                blockNumber: block.number
            });
        }

        return abi.encode(reserves);
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

        PoolReserves[] memory reserves = abi.decode(data[0], (PoolReserves[]));

        PoolAlert[] memory alerts = new PoolAlert[](reserves.length);
        uint256 alertCount = 0;

        for (uint256 i = 0; i < reserves.length; i++) {
            PoolReserves memory pool = reserves[i];

            if (
                uint256(pool.reserve0) < MIN_RESERVE_THRESHOLD ||
                uint256(pool.reserve1) < MIN_RESERVE_THRESHOLD
            ) {
                alerts[alertCount++] = PoolAlert({
                    pool: pool.pool,
                    reserve0: pool.reserve0,
                    reserve1: pool.reserve1,
                    minThreshold: MIN_RESERVE_THRESHOLD
                });
            }
        }

        if (alertCount > 0) {
            // Return the first alert's data in the format expected by response_function:
            // handleUnhealthyPools((address,address,address,uint112,uint112,uint256,uint256,bool)[])
            PoolAlert memory firstAlert = alerts[0];

            // Create a single-element array in the expected format
            PoolHealthAlert[] memory healthAlerts = new PoolHealthAlert[](1);
            healthAlerts[0] = PoolHealthAlert({
                pool: firstAlert.pool,
                token0: address(0), // would be determined by TrapConfig
                token1: address(0), // would be determined by TrapConfig
                reserve0: firstAlert.reserve0,
                reserve1: firstAlert.reserve1,
                minThreshold: firstAlert.minThreshold,
                currentRatio: 0, // would be calculated by TrapConfig
                isHealthy: false
            });

            return (true, abi.encode(healthAlerts));
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredPools() external view returns (address[] memory) {
        return monitoredPools;
    }

    // NOTE: For testing purposes only
    function addMonitoredPool(address pool) external {
        monitoredPools.push(pool);
    }

    // NOTE: For testing purposes only
    function getMinThreshold() external pure returns (uint256) {
        return MIN_RESERVE_THRESHOLD;
    }
}
