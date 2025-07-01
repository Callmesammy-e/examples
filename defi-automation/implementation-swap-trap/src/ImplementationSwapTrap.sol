// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IOwnable {
    function owner() external view returns (address);
}

interface ITransparentProxy {
    function admin() external view returns (address);
}

/**
 * @title ImplementationSwapTrap
 * @notice Monitor proxy contracts for ownership and admin changes
 * @dev Simple trap that monitors owner() and admin() functions on proxy contracts
 */
contract ImplementationSwapTrap is ITrap {
    struct ProxyInfo {
        address proxy;
        bool hasOwner;
        bool hasAdmin;
    }

    struct ProxyState {
        address proxy;
        address owner;
        address admin;
        uint256 blockNumber;
    }

    struct ProxyChange {
        address proxy;
        address oldOwner;
        address newOwner;
        address oldAdmin;
        address newAdmin;
        string changeType; // "owner", "admin", "both"
    }

    ProxyInfo[] public monitoredProxies;

    constructor() {
        // Monitor real DeFi proxies with owner() functions
        monitoredProxies.push(
            ProxyInfo({
                proxy: 0xEe6A57eC80ea46401049E92587E52f5Ec1c24785, // Uniswap V3 proxy
                hasOwner: true,
                hasAdmin: false
            })
        );

        monitoredProxies.push(
            ProxyInfo({
                proxy: 0xc00e94Cb662C3520282E6f5717214004A7f26888, // Compound token
                hasOwner: true,
                hasAdmin: false
            })
        );

        monitoredProxies.push(
            ProxyInfo({
                proxy: 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9, // AAVE proxy
                hasOwner: false,
                hasAdmin: true
            })
        );
    }

    function collect() external view override returns (bytes memory) {
        ProxyState[] memory states = new ProxyState[](monitoredProxies.length);

        for (uint256 i = 0; i < monitoredProxies.length; i++) {
            ProxyInfo memory info = monitoredProxies[i];

            address owner = address(0);
            address admin = address(0);

            // Try to get owner
            if (info.hasOwner) {
                try IOwnable(info.proxy).owner() returns (address _owner) {
                    owner = _owner;
                } catch {}
            }

            // Try to get admin
            if (info.hasAdmin) {
                try ITransparentProxy(info.proxy).admin() returns (
                    address _admin
                ) {
                    admin = _admin;
                } catch {}
            }

            states[i] = ProxyState({
                proxy: info.proxy,
                owner: owner,
                admin: admin,
                blockNumber: block.number
            });
        }

        return abi.encode(states);
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

        ProxyState[] memory current = abi.decode(data[0], (ProxyState[]));
        ProxyState[] memory previous = abi.decode(data[1], (ProxyState[]));

        if (current.length != previous.length) {
            return (false, "");
        }

        ProxyChange[] memory changes = new ProxyChange[](current.length);
        uint256 changeCount = 0;

        for (uint256 i = 0; i < current.length; i++) {
            bool ownerChanged = current[i].owner != previous[i].owner;
            bool adminChanged = current[i].admin != previous[i].admin;

            if (ownerChanged || adminChanged) {
                string memory changeType = "none";
                if (ownerChanged && adminChanged) {
                    changeType = "both";
                } else if (ownerChanged) {
                    changeType = "owner";
                } else if (adminChanged) {
                    changeType = "admin";
                }

                changes[changeCount++] = ProxyChange({
                    proxy: current[i].proxy,
                    oldOwner: previous[i].owner,
                    newOwner: current[i].owner,
                    oldAdmin: previous[i].admin,
                    newAdmin: current[i].admin,
                    changeType: changeType
                });
            }
        }

        if (changeCount > 0) {
            // Return the first change's data in the format expected by response_function:
            // handleProxyUpgrade(address,address,address,string)
            ProxyChange memory firstChange = changes[0];
            address newAddress = firstChange.newOwner != address(0)
                ? firstChange.newOwner
                : firstChange.newAdmin;
            return (
                true,
                abi.encode(
                    firstChange.proxy, // proxy address
                    address(0), // old implementation (would be determined by TrapConfig)
                    newAddress, // new implementation/owner/admin
                    firstChange.changeType // change description
                )
            );
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredProxies() external view returns (ProxyInfo[] memory) {
        return monitoredProxies;
    }

    // NOTE: For testing purposes only
    function addMonitoredProxy(
        address proxy,
        bool hasOwner,
        bool hasAdmin
    ) external {
        monitoredProxies.push(
            ProxyInfo({proxy: proxy, hasOwner: hasOwner, hasAdmin: hasAdmin})
        );
    }
}
