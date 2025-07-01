// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IChainlinkOracle {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title StaleOracleTrap
 * @notice Monitor Chainlink oracles for stale price data
 * @dev Simple trap that detects when oracle updates are delayed
 */
contract StaleOracleTrap is ITrap {
    uint256 constant MAX_STALENESS = 3600; // 1 hour

    struct OracleData {
        address oracle;
        int256 price;
        uint256 updatedAt;
        uint256 currentTime;
    }

    struct StaleAlert {
        address oracle;
        int256 price;
        uint256 updatedAt;
        uint256 staleness;
    }

    address[] public monitoredOracles;

    constructor() {
        // Monitor major price feeds
        monitoredOracles.push(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // ETH/USD
        monitoredOracles.push(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c); // BTC/USD
        monitoredOracles.push(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6); // USDC/USD
    }

    function collect() external view override returns (bytes memory) {
        OracleData[] memory oracleData = new OracleData[](
            monitoredOracles.length
        );

        for (uint256 i = 0; i < monitoredOracles.length; i++) {
            address oracle = monitoredOracles[i];

            int256 price = 0;
            uint256 updatedAt = 0;

            try IChainlinkOracle(oracle).latestRoundData() returns (
                uint80,
                int256 _price,
                uint256,
                uint256 _updatedAt,
                uint80
            ) {
                price = _price;
                updatedAt = _updatedAt;
            } catch {}

            oracleData[i] = OracleData({
                oracle: oracle,
                price: price,
                updatedAt: updatedAt,
                currentTime: block.timestamp
            });
        }

        return abi.encode(oracleData);
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

        OracleData[] memory oracles = abi.decode(data[0], (OracleData[]));

        StaleAlert[] memory alerts = new StaleAlert[](oracles.length);
        uint256 alertCount = 0;

        for (uint256 i = 0; i < oracles.length; i++) {
            OracleData memory oracle = oracles[i];

            if (oracle.currentTime > oracle.updatedAt) {
                uint256 staleness = oracle.currentTime - oracle.updatedAt;

                if (staleness > MAX_STALENESS) {
                    alerts[alertCount++] = StaleAlert({
                        oracle: oracle.oracle,
                        price: oracle.price,
                        updatedAt: oracle.updatedAt,
                        staleness: staleness
                    });
                }
            }
        }

        if (alertCount > 0) {
            // Return the first alert's data in the format expected by response_function
            // alertStaleOracle(address,int256,uint256,uint256)
            StaleAlert memory firstAlert = alerts[0];
            return (
                true,
                abi.encode(
                    firstAlert.oracle,
                    firstAlert.price,
                    firstAlert.updatedAt,
                    firstAlert.staleness
                )
            );
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredOracles() external view returns (address[] memory) {
        return monitoredOracles;
    }

    // NOTE: For testing purposes only
    function addMonitoredOracle(address oracle) external {
        monitoredOracles.push(oracle);
    }

    // NOTE: For testing purposes only
    function getMaxStaleness() external pure returns (uint256) {
        return MAX_STALENESS;
    }
}
