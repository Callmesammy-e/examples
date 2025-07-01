# Scheduler Trap

A simple time/block-based scheduler trap for the Drosera protocol that demonstrates basic triggering without external contract dependencies.

## Overview

This trap shows how to create a scheduler that triggers at a specific block number or timestamp. It's one of the simplest possible traps, using only built-in blockchain data (`block.number` and `block.timestamp`).

## How it Works

1. **collect()**: Returns current block number and timestamp
2. **shouldRespond()**: Checks if the target block/time has been reached
3. **Configuration**: Uses hardcoded constants for target values

## Configuration

The trap is configured with constants in the contract:

- `TARGET_BLOCK`: Block number to trigger at (default: 20,000,000)
- `TARGET_TIMESTAMP`: Unix timestamp to trigger at (default: Jan 1, 2025)
- `USE_BLOCK_NUMBER`: Choose block-based (true) or time-based (false) scheduling

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

- ✅ No external contract dependencies
- ✅ Simple hardcoded configuration
- ✅ Supports both block and time-based scheduling
- ✅ Helper functions for remaining time/blocks
- ✅ Comprehensive test coverage

## Usage Pattern

This trap demonstrates the basic Drosera pattern:
- Constructor with no arguments (runs every block)
- `collect()` gathers current state data
- `shouldRespond()` evaluates trigger conditions
- Constants for all configuration (no dynamic parameters)