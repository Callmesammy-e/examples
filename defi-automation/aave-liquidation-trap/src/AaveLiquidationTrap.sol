// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IAaveV3Pool {
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/**
 * @title AaveLiquidationTrap
 * @notice Monitor AAVE V3 positions for liquidation risk
 * @dev Simple trap that checks health factors below liquidation threshold
 */
contract AaveLiquidationTrap is ITrap {
    address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    uint256 constant LIQUIDATION_THRESHOLD = 1.05e18; // 1.05 health factor

    struct UserPosition {
        address user;
        uint256 healthFactor;
        uint256 totalCollateral;
        uint256 totalDebt;
        uint256 blockNumber;
    }

    struct LiquidationAlert {
        address user;
        uint256 healthFactor;
        uint256 totalCollateral;
        uint256 totalDebt;
    }

    address[] public monitoredUsers;

    constructor() {
        // Monitor some example addresses (real borrowers would be added dynamically)
        monitoredUsers.push(0x2767eDfee9f5ba743511Ee4187A596B302B43938);
    }

    function collect() external view override returns (bytes memory) {
        UserPosition[] memory positions = new UserPosition[](
            monitoredUsers.length
        );
        IAaveV3Pool pool = IAaveV3Pool(AAVE_V3_POOL);

        for (uint256 i = 0; i < monitoredUsers.length; i++) {
            address user = monitoredUsers[i];

            try pool.getUserAccountData(user) returns (
                uint256 totalCollateralBase,
                uint256 totalDebtBase,
                uint256,
                uint256,
                uint256,
                uint256 healthFactor
            ) {
                positions[i] = UserPosition({
                    user: user,
                    healthFactor: healthFactor,
                    totalCollateral: totalCollateralBase,
                    totalDebt: totalDebtBase,
                    blockNumber: block.number
                });
            } catch {
                revert();
                // // If call fails, set health factor to max to indicate no risk
                // positions[i] = UserPosition({
                //     user: user,
                //     healthFactor: type(uint256).max,
                //     totalCollateral: 0,
                //     totalDebt: 0,
                //     blockNumber: block.number
                // });
            }
        }

        return abi.encode(positions);
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

        UserPosition[] memory positions = abi.decode(data[0], (UserPosition[]));

        LiquidationAlert[] memory alerts = new LiquidationAlert[](
            positions.length
        );
        uint256 alertCount = 0;

        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition memory position = positions[i];

            // Trigger if health factor is below threshold and user has debt
            if (
                position.healthFactor < LIQUIDATION_THRESHOLD &&
                position.totalDebt > 0
            ) {
                alerts[alertCount++] = LiquidationAlert({
                    user: position.user,
                    healthFactor: position.healthFactor,
                    totalCollateral: position.totalCollateral,
                    totalDebt: position.totalDebt
                });
            }
        }

        if (alertCount > 0) {
            // Return the first alert's data in the format expected by response_function:
            // liquidatePosition(address,address,address,uint256)
            LiquidationAlert memory firstAlert = alerts[0];
            return (
                true,
                abi.encode(
                    firstAlert.user, // user to liquidate
                    address(0), // collateral asset (would be determined by TrapConfig)
                    address(0), // debt asset (would be determined by TrapConfig)
                    firstAlert.totalDebt // debt amount to cover
                )
            );
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredUsers() external view returns (address[] memory) {
        return monitoredUsers;
    }

    // NOTE: For testing purposes only
    function addMonitoredUser(address user) external {
        monitoredUsers.push(user);
    }

    // NOTE: For testing purposes only
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }
}
