# Liquidity Pool Health Monitor

A trap that monitors Uniswap V2 liquidity pool health metrics, triggering when pools become unhealthy due to low liquidity, extreme price deviations, or other risk factors.

## Overview

This trap demonstrates advanced DeFi monitoring by tracking the health of major Uniswap V2 liquidity pools. It calculates liquidity levels, price ratios, and other metrics to detect when pools may be at risk or experiencing unusual activity.

## How it Works

1. **collect()**: Reads reserves, token addresses, and calculates health metrics for each monitored pool
2. **shouldRespond()**: Uses edge detection to trigger only when pools transition from healthy to unhealthy
3. **Health Assessment**: Evaluates multiple metrics including liquidity depth and reserve ratios

## Monitored Pools

The trap monitors these real Uniswap V2 pools on mainnet:
- **USDC/WETH**: 0xB4e16d0168e52d35CaCD2c6185b44281eC28C9Dc
- **USDT/WETH**: 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852  
- **DAI/WETH**: 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11

## Health Criteria

A pool is considered unhealthy if:
- **Total liquidity** < $1,000,000 USD equivalent
- **Reserve ratios** fall below minimum thresholds
- **Price deviations** exceed 5% from expected ranges

## Testing

```bash
# Install dependencies
bun install

# Run tests
forge test

# Run with verbose output
forge test -vv
```

## Key Features

- ✅ Real Uniswap V2 pool integration
- ✅ Multi-metric health assessment
- ✅ Liquidity calculation in USD equivalent
- ✅ Price ratio computation with decimal normalization
- ✅ Edge transition detection (prevents infinite triggering)
- ✅ Comprehensive test coverage with pool mocking
- ✅ Support for multiple pool monitoring

## AMM Monitoring Patterns

This trap demonstrates:
- **Uniswap V2 Integration**: Reading reserves and pool data from real DEX contracts
- **Liquidity Assessment**: Converting token reserves to USD-equivalent values
- **Price Ratio Calculations**: Handling different token decimals and computing normalized ratios
- **Multi-Pool Health**: Monitoring several pools with different risk profiles
- **DeFi Risk Management**: Detecting conditions that could lead to impermanent loss or liquidity crises

## Response Contract

The trap is designed to work with a pool management contract that implements:
```solidity
function handleUnhealthyPools(PoolHealth[] calldata pools) external;
```

This function would receive alerts about unhealthy pools and can:
- Pause affected trading pairs
- Adjust liquidity mining incentives
- Alert liquidity providers about risks
- Trigger rebalancing mechanisms
- Execute emergency pool management procedures

## Production Applications

- **DeFi Protocol Risk Management**: Monitor critical liquidity pools for protocol health
- **Liquidity Provider Protection**: Alert LPs about potential impermanent loss situations
- **Market Making Operations**: Detect when pools need liquidity injection or rebalancing
- **Cross-DEX Arbitrage**: Identify price discrepancies and liquidity opportunities
- **Protocol Treasury Management**: Monitor pools holding treasury assets