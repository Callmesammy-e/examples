# Sudden Balance Drop Trap

A critical security monitoring trap that detects sudden drops in vault and treasury token balances, which may indicate exploits, hacks, or unauthorized fund movements.

## Overview

This trap monitors multiple vaults and treasury addresses for sudden drops in token balances. It's designed to catch potential security incidents early by tracking balance changes across multiple vault/token combinations and triggering alerts when drops exceed configurable thresholds.

## Features

- **Multi-Vault Monitoring**: Tracks 3 critical vaults (Main Treasury, Operations Vault, Emergency Reserve)
- **Multi-Token Support**: Monitors 3 stablecoins (USDC, USDT, DAI) across each vault
- **Configurable Thresholds**: 10% warning threshold, 25% critical threshold
- **Minimum Balance Filter**: Only monitors balances above $10,000 to reduce noise
- **Severity Classification**: Automatic severity assessment (warning/critical)
- **Edge Detection**: Prevents infinite triggering by comparing consecutive readings

## Architecture

### Monitored Assets

**Vaults:**
- Main Treasury: `0x742d35cC6634C0532925a3B8d80a6B24C5D06e41`
- Operations Vault: `0x8Ba1f109551Bd432803012645Aac136C40872A5F`
- Emergency Reserve: `0xdAC17F958D2ee523a2206206994597C13D831ec7`

**Tokens:**
- USDC: `0xA0b86a33E6441fD9Eec086d4E61ef0b5D31a5e7D`
- USDT: `0xdAC17F958D2ee523a2206206994597C13D831ec7`
- DAI: `0x6B175474E89094C44Da98b954EedeAC495271d0F`

**Total Combinations**: 9 (3 vaults × 3 tokens)

### Detection Logic

1. **Balance Collection**: Collects current balances for all vault/token combinations
2. **Drop Calculation**: Compares current vs previous balances to calculate percentage drops
3. **Threshold Evaluation**: Checks if drops exceed configurable thresholds
4. **Minimum Balance Filter**: Ignores drops on balances below $10,000
5. **Severity Assessment**: Classifies drops as warning (10-25%) or critical (25%+)

### Trigger Conditions

The trap triggers when:
- Balance drops ≥10% in a single block
- Previous balance was ≥$10,000 USD equivalent
- Drop occurs on any monitored vault/token combination

## Configuration

### Drop Thresholds
```solidity
uint256 constant MAX_DROP_BPS = 1000;      // 10% warning threshold
uint256 constant CRITICAL_DROP_BPS = 2500; // 25% critical threshold
uint256 constant MIN_BALANCE_USD = 10000e18; // $10k minimum monitoring threshold
```

### Response Settings
- **Cooldown**: 50 blocks between triggers
- **Operators**: 2-5 operators required for consensus
- **Emergency Mode**: Enabled for immediate response

## Testing

The trap includes comprehensive tests covering:

- **Normal Operation**: Validates data collection and basic functionality
- **Drop Detection**: Tests various drop scenarios and threshold triggers
- **Edge Cases**: Handles insufficient data, low balances, and multiple drops
- **Calculation Logic**: Verifies drop percentage calculations and severity assessment
- **Fuzz Testing**: Validates behavior across random balance combinations

### Running Tests

```bash
# Install dependencies
bun install

# Run all tests
forge test

# Run specific test
forge test --match-test test_SuddenBalanceDrop

# Run with gas reporting
forge test --gas-report
```

### Key Test Scenarios

1. **No Drops**: Identical balances should not trigger
2. **Small Drops**: <10% drops should be ignored
3. **Warning Drops**: 10-25% drops should trigger with warning severity
4. **Critical Drops**: >25% drops should trigger with critical severity
5. **Low Balance Drops**: Drops on balances <$10k should be ignored
6. **Multiple Vault Drops**: Multiple simultaneous drops should be detected
7. **Balance Increases**: Positive balance changes should not trigger

## Implementation Details

### Data Structures

```solidity
struct VaultBalance {
    address vault;          // Vault/treasury address
    address token;          // Token contract address
    uint256 balance;        // Current token balance
    uint256 blockNumber;    // Block when balance was recorded
    string tokenSymbol;     // Token symbol for reporting
}
```

### Core Functions

- `collect()`: Collects current balances for all monitored combinations
- `shouldRespond()`: Analyzes balance changes and determines if trap should trigger
- `analyzeBalanceDrop()`: Calculates drop percentages and severity levels
- `checkVaultBalance()`: Queries specific vault/token balance
- `estimateUSDValue()`: Converts token balances to USD estimates

### Security Considerations

1. **Address Validation**: Uses checksummed addresses to prevent typos
2. **Minimum Thresholds**: Filters out noise from small balance changes
3. **Edge Detection**: Prevents infinite triggering on persistent conditions
4. **Data Validation**: Validates input data structure and completeness
5. **Overflow Protection**: Uses safe math for percentage calculations

## Emergency Response

When triggered, the trap can initiate:

1. **Immediate Actions**:
   - Pause withdrawal functions
   - Alert security team
   - Create incident reports

2. **Investigation Actions**:
   - Snapshot blockchain state
   - Analyze recent transactions
   - Check smart contract logs

3. **Communication Actions**:
   - Alert stakeholders
   - Update status pages
   - Prepare incident documentation

## Monitoring Dashboard

The trap provides several view functions for monitoring:

- `getMonitoredVaults()`: Returns all monitored vault addresses
- `getMonitoredTokens()`: Returns all monitored token addresses
- `getDropThresholds()`: Returns configured thresholds
- `getMonitoredCombinations()`: Returns total combinations monitored

## Potential Enhancements

1. **Dynamic Thresholds**: Adjust thresholds based on volatility
2. **Price Oracle Integration**: Use real-time prices instead of assuming stablecoin parity
3. **Historical Analysis**: Track balance trends over longer periods
4. **Multi-Block Analysis**: Detect sustained drops over multiple blocks
5. **Whitelist Integration**: Ignore authorized large withdrawals
6. **Cross-Chain Monitoring**: Extend to monitor L2 and other chain balances

## Use Cases

This trap is particularly valuable for:

- **Protocol Treasuries**: Monitor DAO and protocol fund security
- **Yield Farming Vaults**: Detect exploitation of farming strategies
- **Lending Protocols**: Monitor collateral and reserve balances
- **DEX Protocols**: Track liquidity pool and fee collection balances
- **Bridge Protocols**: Monitor locked token balances for bridge security

## License

MIT License - see LICENSE file for details.