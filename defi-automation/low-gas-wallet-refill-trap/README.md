# Low Gas Wallet Refill Trap

A trap that monitors a wallet's ETH balance and triggers a refill when it falls below a specified threshold.

## Overview

This trap demonstrates basic balance monitoring by watching a target wallet address and triggering when its ETH balance drops below 0.1 ETH. It's useful for maintaining operational wallets that need a minimum balance for gas fees.

## How it Works

1. **collect()**: Reads the target wallet's current ETH balance using `address.balance`
2. **shouldRespond()**: Compares balance against threshold (0.1 ETH)
3. **Response**: When triggered, requests a refill of 0.5 ETH to the wallet

## Configuration

The trap is configured with constants in the contract:

- `TARGET_WALLET`: Address to monitor (0x742d35cC6634C0532925a3B8d80a6B24C5D06e41)
- `MIN_BALANCE`: Threshold balance (0.1 ETH)
- `REFILL_AMOUNT`: Amount to request when refilling (0.5 ETH)

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

- ✅ ETH balance monitoring for any address
- ✅ Configurable threshold and refill amounts
- ✅ Cooldown period to prevent rapid refills
- ✅ Helper functions for balance calculations
- ✅ Comprehensive test coverage including fuzz testing

## Usage Pattern

This trap demonstrates:
- External address balance reading
- Threshold-based triggering logic
- Practical real-world use case for operational maintenance
- Response contract integration for automated refills

## Response Contract

The trap is designed to work with a treasury or refill contract that implements:
```solidity
function refillWallet(address wallet, uint256 amount) external;
```

This function would be called when the trap triggers, automatically sending ETH to the low-balance wallet.