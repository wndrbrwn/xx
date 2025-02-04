// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

interface IVault {
    struct LiquidityProvider {
        uint256 cumulativeTransactionFeeLast;   // 진입 시점까지 쌓여있는 수수료
        uint256 userLP;     // 사용자 보유 LP 토큰 개수
    }

    /// @notice Emitted when trader deposit collateral into vault
    /// @param collateralToken The address of token deposited
    /// @param trader The address of trader
    /// @param amount The amount of token deposited
    event Deposited(address indexed collateralToken, address indexed trader, uint256 amount);

    /// @notice Emitted when trader withdraw collateral from vault
    /// @param collateralToken The address of token withdrawn
    /// @param trader The address of trader
    /// @param amount The amount of token withdrawn
    event Withdrawn(address indexed collateralToken, address indexed trader, uint256 amount);

    /// @notice Emitted when clearingHouse is changed
    /// @param clearingHouse The address of clearingHouse
    event ClearingHouseChanged(address indexed clearingHouse);

    /// @notice Get settlement token decimals
    /// @return decimals The decimals of settlement token
    function decimals() external view returns (uint8 decimals);

    /// @notice Deposit collateral into vault
    /// @param amount The amount of the token to deposit
    function deposit(uint256 amount) external;

    /// @notice Deposit the collateral token for other account
    /// @param to The address of the account to deposit to
    /// @param amount The amount of the token to deposit
    function depositFor(
        address to,
        uint256 amount
    ) external;

    /// @notice Withdraw collateral from vault
    /// @param amount The amount of the token to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Withdraw all free collateral from vault
    function withdrawAll() external;

    /// @notice Update the balance of Vault of the specified collateral token and trader
    /// @param trader The address of the trader
    /// @param amount The amount of the token to update
    /// @param isPlus Is the amount positive(true) or negative(false)
    function updateCollateral(address trader, uint256 amount, bool isPlus) external;

    /// @notice Get the total collateral value of trader
    /// @param trader The address of the trader
    /// @return totalCollateral total collateral
    function getTotalCollateral(address trader) external view returns (uint256 totalCollateral);

    /// @notice Get the used collateral value of trader
    /// @param trader The address of the trader
    /// @return useCollateral used collateral
    function getUseCollateral(address trader) external view returns (uint256 useCollateral);

    /// @notice Get the free collateral value denominated in the settlement token of the specified trader
    /// @param trader The address of the trader
    /// @return freeCollateral the value (in settlement token's decimals) of free collateral available
    ///         for withdraw or opening new positions or orders)
    function getFreeCollateral(address trader) external view returns (uint256 freeCollateral);

    /// @notice Update the balance of LP token of the trader
    /// @param trader The address of the trader
    /// @param pool The address of the liquidity pool contract
    /// @param amount The amount of the token to update
    /// @param isPlus Is the amount positive(true) or negative(false)
    function updateUserLP(address trader, address pool, uint256 amount, bool isPlus) external;

    /// @notice Claim the reward of the trader
    /// @param trader The address of the trader
    /// @param pool The address of the liquidity pool contract
    function claimRewards(address trader, address pool) external;

    /// @notice Set the cumulative transaction fee per 1LP of liquidity pool
    /// @param pool The address of the liquidity pool contract
    /// @param fee transaction fee per 1LP
    function setCumulativeTransactionFee(address pool, uint256 fee) external;

    /// @notice Get the cumulative transaction fee per 1LP of liquidity pool
    /// @param pool The address of the liquidity pool contract
    /// @return cumulativeTransactionFee cumulative transaction fee per 1LP
    function getCumulativeTransactionFee(address pool) external  view returns (uint256 cumulativeTransactionFee);

    /// @notice Get the trader's LP token balance.
    /// @param trader The address of the trader
    /// @param pool The address of the liquidity pool contract
    function getUserLP(address trader, address pool) external view returns(uint256);

}