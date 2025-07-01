// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

/**
 * @title LowGasWalletTrap
 * @notice Monitor wallet ETH balance and trigger refill when below threshold
 * @dev Simple trap that detects when monitored wallets need ETH refills
 */
contract LowGasWalletTrap is ITrap {
    uint256 constant MIN_BALANCE = 0.1 ether;
    uint256 constant REFILL_AMOUNT = 0.5 ether;

    struct WalletBalance {
        address wallet;
        uint256 balance;
        uint256 blockNumber;
    }

    struct RefillAlert {
        address wallet;
        uint256 balance;
        uint256 refillAmount;
    }

    address[] public monitoredWallets;

    constructor() {
        // Monitor important wallet addresses
        monitoredWallets.push(0x742d35cC6634C0532925a3B8d80a6B24C5D06e41); // Treasury
        monitoredWallets.push(0x8Ba1f109551Bd432803012645Aac136C40872A5F); // Operations
        monitoredWallets.push(0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503); // Bot wallet
    }

    function collect() external view override returns (bytes memory) {
        WalletBalance[] memory balances = new WalletBalance[](
            monitoredWallets.length
        );

        for (uint256 i = 0; i < monitoredWallets.length; i++) {
            address wallet = monitoredWallets[i];

            balances[i] = WalletBalance({
                wallet: wallet,
                balance: wallet.balance,
                blockNumber: block.number
            });
        }

        return abi.encode(balances);
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

        WalletBalance[] memory balances = abi.decode(
            data[0],
            (WalletBalance[])
        );

        RefillAlert[] memory alerts = new RefillAlert[](balances.length);
        uint256 alertCount = 0;

        for (uint256 i = 0; i < balances.length; i++) {
            WalletBalance memory wallet = balances[i];

            if (wallet.balance < MIN_BALANCE) {
                alerts[alertCount++] = RefillAlert({
                    wallet: wallet.wallet,
                    balance: wallet.balance,
                    refillAmount: REFILL_AMOUNT
                });
            }
        }

        if (alertCount > 0) {
            // Return the first alert's data in the format expected by response_function:
            // refillWallet(address,uint256)
            RefillAlert memory firstAlert = alerts[0];
            return (
                true,
                abi.encode(
                    firstAlert.wallet, // wallet to refill
                    firstAlert.refillAmount // amount to refill
                )
            );
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredWallets() external view returns (address[] memory) {
        return monitoredWallets;
    }

    // NOTE: For testing purposes only
    function addMonitoredWallet(address wallet) external {
        monitoredWallets.push(wallet);
    }

    // NOTE: For testing purposes only
    function getMinBalance() external pure returns (uint256) {
        return MIN_BALANCE;
    }

    // NOTE: For testing purposes only
    function getRefillAmount() external pure returns (uint256) {
        return REFILL_AMOUNT;
    }
}
