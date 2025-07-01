// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IFeeContract {
    function performanceFee() external view returns (uint256);
    function fee() external view returns (uint256);
    function feeRate() external view returns (uint256);
}

/**
 * @title SimpleFeeChangeTrap
 * @notice Monitor protocol fees for excessive changes
 * @dev Simple trap that detects when fees exceed reasonable thresholds
 */
contract SimpleFeeChangeTrap is ITrap {
    uint256 constant MAX_FEE_BPS = 2000; // 20% maximum fee

    struct FeeData {
        address protocol;
        uint256 fee;
        uint256 blockNumber;
    }

    struct FeeAlert {
        address protocol;
        uint256 fee;
        uint256 maxFee;
    }

    address[] public monitoredProtocols;

    constructor() {
        // Monitor some real protocol contracts that have fee functions
        monitoredProtocols.push(0x742d35cC6634C0532925a3B8d80a6B24C5D06e41); // Example vault
        monitoredProtocols.push(0x8Ba1f109551Bd432803012645Aac136C40872A5F); // Example protocol
        monitoredProtocols.push(0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503); // Example contract
    }

    function collect() external view override returns (bytes memory) {
        FeeData[] memory fees = new FeeData[](monitoredProtocols.length);

        for (uint256 i = 0; i < monitoredProtocols.length; i++) {
            address protocol = monitoredProtocols[i];
            uint256 fee = 0;

            // Try different common fee function names
            try IFeeContract(protocol).performanceFee() returns (uint256 _fee) {
                fee = _fee;
            } catch {
                try IFeeContract(protocol).fee() returns (uint256 _fee) {
                    fee = _fee;
                } catch {
                    try IFeeContract(protocol).feeRate() returns (
                        uint256 _fee
                    ) {
                        fee = _fee;
                    } catch {}
                }
            }

            fees[i] = FeeData({
                protocol: protocol,
                fee: fee,
                blockNumber: block.number
            });
        }

        return abi.encode(fees);
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

        FeeData[] memory fees = abi.decode(data[0], (FeeData[]));

        FeeAlert[] memory alerts = new FeeAlert[](fees.length);
        uint256 alertCount = 0;

        for (uint256 i = 0; i < fees.length; i++) {
            FeeData memory protocol = fees[i];

            if (protocol.fee > MAX_FEE_BPS) {
                alerts[alertCount++] = FeeAlert({
                    protocol: protocol.protocol,
                    fee: protocol.fee,
                    maxFee: MAX_FEE_BPS
                });
            }
        }

        if (alertCount > 0) {
            // Return the first alert's fee value in the format expected by response_function:
            // handleViolation(uint256)
            FeeAlert memory firstAlert = alerts[0];
            return (true, abi.encode(firstAlert.fee));
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredProtocols() external view returns (address[] memory) {
        return monitoredProtocols;
    }

    // NOTE: For testing purposes only
    function addMonitoredProtocol(address protocol) external {
        monitoredProtocols.push(protocol);
    }

    // NOTE: For testing purposes only
    function getMaxFeeBps() external pure returns (uint256) {
        return MAX_FEE_BPS;
    }
}
