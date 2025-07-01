# Token Supply Watch Trap

A trap that monitors ERC20 token total supply for unexpected changes, triggering when supply increases or decreases beyond safe thresholds in a single block.

## Overview

This trap demonstrates supply monitoring by tracking the `totalSupply()` of major stablecoins and detecting suspicious minting or burning events. It's critical for detecting unauthorized token creation, flash loan attacks, or protocol exploits involving supply manipulation.

## How it Works

1. **collect()**: Reads current `totalSupply()` for all monitored tokens
2. **shouldRespond()**: Compares current supply with previous block to detect large changes
3. **Threshold Analysis**: Triggers on percentage changes above safety limits AND minimum absolute amounts

## Monitored Tokens

The trap monitors these real mainnet stablecoins:
- **USDC**: 0xA0b86a33E6441fD9Eec086d4E61ef0b5D31a5e7D (5% max increase threshold)
- **USDT**: 0xdAC17F958D2ee523a2206206994597C13D831ec7 (5% max increase threshold)  
- **DAI**: 0x6B175474E89094C44Da98b954EedeAC495271d0F (5% max increase threshold)

## Safety Thresholds

The trap triggers when:
- **Supply increase** > 5% in a single block AND > 1M tokens absolute change
- **Supply decrease** > 3% in a single block AND > 1M tokens absolute change

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

- ✅ Real stablecoin supply monitoring
- ✅ Percentage-based thresholds with minimum absolute change protection
- ✅ Both increase and decrease detection
- ✅ Dual protection (relative % + absolute minimum)
- ✅ Comprehensive helper functions for supply analysis
- ✅ Fuzz testing for edge cases
- ✅ High-security configuration (private trap with whitelisted operators)

## Supply Monitoring Patterns

This trap demonstrates:
- **ERC20 Supply Tracking**: Reading `totalSupply()` across multiple tokens
- **Percentage Change Detection**: Calculating basis point changes between blocks
- **Dual Threshold Logic**: Both relative (%) and absolute (min amount) protections
- **Historical Comparison**: Requiring previous data to detect changes
- **Security-First Design**: Private trap with trusted operator requirements

## Use Cases

### **Critical Security Monitoring:**
- **Unauthorized Minting**: Detect if token contracts are compromised and printing excess tokens
- **Flash Loan Exploits**: Catch attacks that manipulate supply during complex DeFi interactions
- **Bridge Exploits**: Monitor wrapped tokens for unauthorized minting from cross-chain attacks
- **Governance Attacks**: Detect if governance contracts are used to mint tokens maliciously

### **Operational Monitoring:**
- **Expected Minting Events**: Verify that planned token releases stay within expected bounds
- **Burn Verification**: Ensure token burns happen as expected for deflationary mechanisms
- **Rebase Monitoring**: Track rebase token supply changes for unusual patterns

## Response Contract

The trap is designed to work with a token security contract that implements:
```solidity
function handleSuspiciousSupplyChange(SupplyData[] calldata flaggedTokens) external;
```

This function would receive alerts about suspicious supply changes and can:
- **Pause protocol interactions** with affected tokens
- **Alert security teams** about potential exploits
- **Trigger emergency procedures** like fund withdrawals or contract upgrades
- **Blacklist tokens** from protocol usage until investigation
- **Execute automatic hedging** strategies to minimize exposure

## Production Applications

- **DeFi Protocol Security**: Monitor tokens accepted as collateral for supply manipulation
- **Treasury Management**: Watch treasury holdings for unexpected supply events
- **Market Making**: Detect supply changes that could affect token pricing
- **Regulatory Compliance**: Track token supply for reporting and compliance requirements
- **Exchange Security**: Monitor listed tokens for suspicious minting/burning activity