// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
}

/**
 * @title MultiTokenBalanceTrap
 * @notice Monitor multiple token balances across different addresses
 * @dev Simple trap that checks if balances fall below minimum thresholds
 */
contract MultiTokenBalanceTrap is ITrap {
    struct TokenConfig {
        address token;
        address account;
        uint256 minBalance;
    }

    struct TokenBalance {
        address token;
        address account;
        uint256 balance;
        uint256 blockNumber;
    }

    struct BalanceAlert {
        address token;
        address account;
        uint256 balance;
        uint256 minBalance;
    }

    struct RefillRequest {
        address token;
        address account;
        uint256 currentBalance;
        uint256 targetBalance;
    }

    TokenConfig[] public monitoredTokens;

    constructor() {
        // Monitor real treasury/vault addresses with major tokens
        monitoredTokens.push(
            TokenConfig({
                token: 0xa0B86a33e6441fD9Eec086d4E61ef0b5D31a5e7D, // USDC
                account: 0x742d35cC6634C0532925a3B8d80a6B24C5D06e41, // Treasury
                minBalance: 100000e6 // 100k USDC
            })
        );

        monitoredTokens.push(
            TokenConfig({
                token: 0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
                account: 0x8Ba1f109551Bd432803012645Aac136C40872A5F, // Operations
                minBalance: 50000e6 // 50k USDT
            })
        );

        monitoredTokens.push(
            TokenConfig({
                token: 0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
                account: 0x742d35cC6634C0532925a3B8d80a6B24C5D06e41, // Treasury
                minBalance: 75000e18 // 75k DAI
            })
        );
    }

    function collect() external view override returns (bytes memory) {
        TokenBalance[] memory balances = new TokenBalance[](
            monitoredTokens.length
        );

        for (uint256 i = 0; i < monitoredTokens.length; i++) {
            TokenConfig memory config = monitoredTokens[i];

            uint256 balance = 0;
            try IERC20(config.token).balanceOf(config.account) returns (
                uint256 _balance
            ) {
                balance = _balance;
            } catch {}

            balances[i] = TokenBalance({
                token: config.token,
                account: config.account,
                balance: balance,
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

        TokenBalance[] memory balances = abi.decode(data[0], (TokenBalance[]));

        // Hard-coded thresholds for each monitored token (USDC, USDT, DAI)
        uint256[] memory thresholds = new uint256[](3);
        thresholds[0] = 100000e6; // 100k USDC
        thresholds[1] = 50000e6; // 50k USDT
        thresholds[2] = 75000e18; // 75k DAI

        BalanceAlert[] memory alerts = new BalanceAlert[](balances.length);
        uint256 alertCount = 0;

        for (uint256 i = 0; i < balances.length && i < thresholds.length; i++) {
            TokenBalance memory balance = balances[i];
            uint256 minBalance = thresholds[i];

            if (balance.balance < minBalance) {
                alerts[alertCount++] = BalanceAlert({
                    token: balance.token,
                    account: balance.account,
                    balance: balance.balance,
                    minBalance: minBalance
                });
            }
        }

        if (alertCount > 0) {
            // Return the first alert's data in the format expected by response_function:
            // refillTokenBalances((address,address,uint256,uint256)[])
            // where the tuple is (token, account, currentBalance, targetBalance)
            BalanceAlert memory firstAlert = alerts[0];

            // Create a single-element array in the expected format
            RefillRequest[] memory requests = new RefillRequest[](1);
            requests[0] = RefillRequest({
                token: firstAlert.token,
                account: firstAlert.account,
                currentBalance: firstAlert.balance,
                targetBalance: firstAlert.minBalance
            });

            return (true, abi.encode(requests));
        }

        return (false, "");
    }

    // NOTE: For testing purposes only
    function getMonitoredTokens() external view returns (TokenConfig[] memory) {
        return monitoredTokens;
    }

    // NOTE: For testing purposes only
    function addMonitoredToken(
        address token,
        address account,
        uint256 minBalance
    ) external {
        monitoredTokens.push(
            TokenConfig({
                token: token,
                account: account,
                minBalance: minBalance
            })
        );
    }
}
