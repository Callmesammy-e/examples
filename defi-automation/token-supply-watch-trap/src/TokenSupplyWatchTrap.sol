// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
}

/**
 * @title TokenSupplyWatchTrap
 * @notice Monitor token supply changes for unexpected mints/burns
 * @dev Simple trap that detects large supply changes between blocks
 */
contract TokenSupplyWatchTrap is ITrap {
    uint256 constant MAX_SUPPLY_CHANGE_BPS = 500; // 5% change threshold
    uint256 constant MIN_SUPPLY_CHANGE = 1000000e6; // 1M minimum change

    struct SupplyData {
        address token;
        uint256 totalSupply;
        uint256 blockNumber;
    }

    struct SupplyChange {
        address token;
        uint256 oldSupply;
        uint256 newSupply;
        uint256 changeBps;
        bool isIncrease;
    }

    struct SupplyAlert {
        address token;
        uint256 oldSupply;
        uint256 newSupply;
    }

    address[] public monitoredTokens;

    constructor() {
        // Monitor major stablecoins for supply changes
        monitoredTokens.push(0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D); // USDC
        monitoredTokens.push(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        monitoredTokens.push(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
    }

    function collect() external view override returns (bytes memory) {
        SupplyData[] memory supplies = new SupplyData[](monitoredTokens.length);

        for (uint256 i = 0; i < monitoredTokens.length; i++) {
            address token = monitoredTokens[i];

            uint256 supply = 0;
            try IERC20(token).totalSupply() returns (uint256 _supply) {
                supply = _supply;
            } catch {}

            supplies[i] = SupplyData({
                token: token,
                totalSupply: supply,
                blockNumber: block.number
            });
        }

        return abi.encode(supplies);
    }

    function shouldRespond(
        bytes[] calldata data
    )
        external
        pure
        override
        returns (bool shouldTrigger, bytes memory responseData)
    {
        if (data.length < 2) {
            return (false, "");
        }

        SupplyData[] memory current = abi.decode(data[0], (SupplyData[]));
        SupplyData[] memory previous = abi.decode(data[1], (SupplyData[]));

        if (current.length != previous.length) {
            return (false, "");
        }

        SupplyChange[] memory changes = new SupplyChange[](current.length);
        uint256 changeCount = 0;

        for (uint256 i = 0; i < current.length; i++) {
            if (current[i].token != previous[i].token) {
                continue;
            }

            uint256 oldSupply = previous[i].totalSupply;
            uint256 newSupply = current[i].totalSupply;

            if (oldSupply == 0 || newSupply == oldSupply) {
                continue;
            }

            uint256 change;
            bool isIncrease;

            if (newSupply > oldSupply) {
                change = newSupply - oldSupply;
                isIncrease = true;
            } else {
                change = oldSupply - newSupply;
                isIncrease = false;
            }

            // Check if change is significant enough
            if (change < MIN_SUPPLY_CHANGE) {
                continue;
            }

            uint256 changeBps = (change * 10000) / oldSupply;

            if (changeBps >= MAX_SUPPLY_CHANGE_BPS) {
                changes[changeCount++] = SupplyChange({
                    token: current[i].token,
                    oldSupply: oldSupply,
                    newSupply: newSupply,
                    changeBps: changeBps,
                    isIncrease: isIncrease
                });
            }
        }

        if (changeCount > 0) {
            // Return the first change's data in the format expected by response_function:
            // handleSuspiciousSupplyChange((address,uint256,uint256)[])
            SupplyChange memory firstChange = changes[0];

            // Create a single-element array in the expected format
            SupplyAlert[] memory alerts = new SupplyAlert[](1);
            alerts[0] = SupplyAlert({
                token: firstChange.token,
                oldSupply: firstChange.oldSupply,
                newSupply: firstChange.newSupply
            });

            return (true, abi.encode(alerts));
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredTokens() external view returns (address[] memory) {
        return monitoredTokens;
    }

    // NOTE: For testing purposes only
    function addMonitoredToken(address token) external {
        monitoredTokens.push(token);
    }

    // NOTE: For testing purposes only
    function getChangeThreshold() external pure returns (uint256) {
        return MAX_SUPPLY_CHANGE_BPS;
    }
}
