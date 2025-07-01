# Simple Fee Change Monitor

**A minimal Drosera trap example that monitors a fee value and triggers when it exceeds 20%.**

## What it does

- Monitors `performanceFee()` on a hardcoded contract address
- Triggers when the fee goes above 2000 basis points (20%)
- Demonstrates the basic Drosera trap pattern

## Key Files

- `SimpleFeeChangeTrap.sol` - The trap (50 lines)
- `MockFeeContract.sol` - Test contract (10 lines)  
- `SimpleFeeChangeTrap.t.sol` - Tests (40 lines)

## How it works

```solidity
contract SimpleFeeChangeTrap is ITrap {
    address constant TARGET = 0x1111...;  // Hardcoded target
    uint256 constant MAX_FEE = 2000;      // 20% threshold
    
    constructor() {} // No arguments, runs every block
    
    function collect() external view returns (bytes memory) {
        // Get current fee from target contract
        uint256 fee = TARGET.performanceFee();
        return abi.encode(fee);
    }
    
    function shouldRespond(bytes[] calldata data) external pure 
        returns (bool, bytes memory) {
        uint256 currentFee = abi.decode(data[0], (uint256));
        
        if (currentFee > MAX_FEE) {
            return (true, abi.encode(currentFee)); // Trigger!
        }
        return (false, "");
    }
}
```

## Test it

```bash
forge test --match-contract SimpleFeeChangeTrap
```

## Key Concepts Demonstrated

1. **No constructor arguments** - All config is hardcoded
2. **State-only monitoring** - Reads contract state, no events
3. **Pure shouldRespond** - No state access in decision logic
4. **Simple response** - Just returns the violating fee value

This shows the essential Drosera pattern without complexity.