# Stale Oracle Trap

A trap that monitors Chainlink price oracles for stale data, triggering when oracle feeds haven't updated within acceptable time limits.

## Overview

This trap demonstrates oracle monitoring by watching the ETH/USD Chainlink price feed and detecting when the data becomes stale (hasn't updated for over 1 hour). It's crucial for DeFi protocols that depend on fresh price data for liquidations, pricing, and other critical operations.

## How it Works

1. **collect()**: Reads oracle price, last update timestamp, and current timestamp from Chainlink
2. **shouldRespond()**: Calculates staleness and triggers if data is older than threshold
3. **Oracle Interface**: Uses standard Chainlink `latestRoundData()` interface

## Configuration

The trap is configured with constants in the contract:

- `ORACLE_ADDRESS`: Chainlink ETH/USD oracle (0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419)
- `MAX_STALENESS`: Maximum allowed staleness (3600 seconds = 1 hour)
- Monitored oracle: ETH/USD price feed on Ethereum mainnet

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

- ✅ Chainlink oracle integration
- ✅ Staleness detection with configurable threshold
- ✅ Underflow protection for timestamp calculations
- ✅ Helper functions for oracle status queries
- ✅ Comprehensive test coverage with mock oracles
- ✅ Fuzz testing for threshold edge cases

## Oracle Monitoring Pattern

This trap demonstrates:
- External oracle data reading
- Time-based staleness detection
- Practical DeFi infrastructure monitoring
- Chainlink oracle interface usage

## Response Contract

The trap is designed to work with an oracle management contract that implements:
```solidity
function alertStaleOracle(address oracle, int256 price, uint256 updatedAt, uint256 staleness) external;
```

This function would be called when the trap triggers, allowing automated response to stale oracle conditions such as:
- Pausing protocol operations
- Switching to backup oracles
- Alerting protocol administrators
- Triggering emergency procedures