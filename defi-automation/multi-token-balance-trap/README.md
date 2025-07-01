# Multi-Token Balance Monitor

A trap that monitors multiple ERC20 token balances across different addresses, triggering when any token balance drops below its configured threshold.

## Overview

This trap demonstrates multi-asset monitoring by tracking USDC, USDT, and DAI balances across Treasury and Operations wallets. It shows how to handle complex data structures and multiple trigger conditions in a single trap.

## How it Works

1. **collect()**: Reads balances for 3 tokens × 2 addresses = 6 total monitored balances
2. **shouldRespond()**: Uses edge detection to trigger only when balances cross below thresholds  
3. **Multi-asset monitoring**: Each token has its own threshold based on typical usage patterns

## Configuration

The trap monitors these real mainnet tokens:
- **USDC**: 0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D (threshold: 100,000 USDC)
- **USDT**: 0xdAC17F958D2ee523a2206206994597C13D831ec7 (threshold: 50,000 USDT)
- **DAI**: 0x6B175474E89094C44Da98b954EedeAC495271d0F (threshold: 75,000 DAI)

Across these addresses:
- **Treasury**: 0x742d35cC6634C0532925a3B8d80a6B24C5D06e41
- **Operations**: 0x8Ba1f109551Bd432803012645Aac136C40872A5F

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

- ✅ Multi-token ERC20 balance monitoring
- ✅ Cross-address balance tracking
- ✅ Edge transition detection (prevents infinite triggering)
- ✅ Configurable thresholds per token type
- ✅ Batch balance collection and response
- ✅ Real mainnet token integration
- ✅ Comprehensive test coverage

## Multi-Asset Patterns

This trap demonstrates:
- **ERC20 Interface Usage**: Standard `balanceOf()` calls across multiple tokens
- **Array Data Handling**: Managing complex data structures in collect/shouldRespond
- **Multi-condition Logic**: Checking multiple balances with different thresholds
- **Edge Detection**: Only triggering on threshold crossings, not continuous low balances

## Response Contract

The trap is designed to work with a treasury management contract that implements:
```solidity
function refillTokenBalances(TokenBalance[] calldata lowBalances) external;
```

This function would receive an array of all tokens needing refills and can:
- Transfer tokens from hot wallets to operational wallets
- Trigger automated rebalancing across addresses
- Alert treasury managers about low balances
- Execute batch token transfers efficiently

## Production Use Cases

- **DeFi Protocol Treasury Management**: Monitor operational fund levels
- **Market Maker Inventory**: Track token balances across trading pairs  
- **Bridge Contract Monitoring**: Ensure sufficient liquidity for cross-chain transfers
- **DAO Treasury Oversight**: Automate fund allocation and rebalancing