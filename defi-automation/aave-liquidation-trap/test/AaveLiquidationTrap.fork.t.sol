// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AaveLiquidationTrap} from "../src/AaveLiquidationTrap.sol";

/**
 * @title AaveLiquidationTrapForkTest
 * @notice Simple fork test for AAVE Liquidation Monitor against Ethereum mainnet
 * @dev Demonstrates trap execution with real AAVE V3 data
 */
// forge test --match-path AaveLiquidationTrap.fork.t.sol -vvv
// forge test --match-test test_ForkExecution -vv
contract AaveLiquidationTrapForkTest is Test {
    AaveLiquidationTrap public trap;

    function setUp() public {
        trap = createForkAndDeployTrap(22727955);
    }

    /// @notice Creates a fork at the specified block and deploys a new trap instance
    /// @param blockNumber The block number to fork at
    /// @return The deployed trap instance
    function createForkAndDeployTrap(
        uint256 blockNumber
    ) internal returns (AaveLiquidationTrap) {
        uint256 forkId = vm.createFork(
            "https://rpc.1.ethereum.chain.kitchen",
            blockNumber
        );
        vm.selectFork(forkId);
        return new AaveLiquidationTrap();
    }

    function test_ForkExecution() public {
        console.log("=== AAVE Liquidation Monitor Fork Test ===");

        // Collect data at current block
        emit log_named_uint("Block 1", block.number);
        bytes memory data1 = trap.collect();
        emit log_named_uint("Data1 length", data1.length);

        // Create fork at next block and deploy trap
        uint256 nextBlock = block.number + 1;
        AaveLiquidationTrap trap2 = createForkAndDeployTrap(nextBlock);

        bytes memory data2 = trap2.collect();
        emit log_named_uint("Block 2", block.number);
        emit log_named_uint("Data2 length", data2.length);

        // Prepare data array for shouldRespond
        bytes[] memory dataArray = new bytes[](2);
        dataArray[0] = data2; // current
        dataArray[1] = data1; // previous

        // Test shouldRespond logic using trap2 from the newer block
        (bool shouldTrigger, bytes memory responseData) = trap2.shouldRespond(
            dataArray
        );

        emit log_named_string("Should trigger", shouldTrigger ? "true" : "false");
        emit log_named_uint("Response length", responseData.length);

        // Display the actual data collected
        AaveLiquidationTrap.UserPosition[] memory positions = abi.decode(
            data2,
            (AaveLiquidationTrap.UserPosition[])
        );

        emit log_named_uint("Users count", positions.length);
        for (uint256 i = 0; i < positions.length; i++) {
            console.log("=== User", i, "===");
            emit log_named_address("User Address", positions[i].user);
            emit log_named_decimal_uint("Health Factor", positions[i].healthFactor, 18);
            emit log_named_decimal_uint("Total Collateral", positions[i].totalCollateral, 8);
            emit log_named_decimal_uint("Total Debt", positions[i].totalDebt, 8);
            emit log_named_uint("Block Number", positions[i].blockNumber);
            console.log("==================");
        }

        if (shouldTrigger) {
            AaveLiquidationTrap.LiquidationAlert[] memory alerts = abi.decode(
                responseData,
                (AaveLiquidationTrap.LiquidationAlert[])
            );
            emit log_named_uint("Liquidation alerts", alerts.length);
        }

        console.log("=== Test completed successfully ===");
    }
}
