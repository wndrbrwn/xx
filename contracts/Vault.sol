// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.26;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import { ClearingHouse } from "./ClearingHouse.sol";

import { IVault } from "./interfaces/IVault.sol";
import { IERC20 } from "./v2-core-contracts/interfaces/IERC20.sol";

contract Vault {

/// state variables
    // --------- IMMUTABLE ---------
    uint8 internal _decimals;
    address internal _settlementToken;  // USDT
    // --------- ^^^^^^^^^ ---------

    address internal _clearingHouse;    // Clearing House Address

    // funding fee
    struct LiquidityProvider {
        uint256 cumulativeTransactionFeeLast;   // 진입 시점까지 쌓여있는 수수료
        uint256 userLP;     // 사용자 보유 LP 토큰 개수
    }

    // 보증금
    struct Collateral {
        uint112 totalCollateral;    // 얼마 가지고 있는지 = useAmount 포함
        uint112 useCollateral;      // 얼마 사용하고 있는지 = 전체 포지션 증거금 합
    }

    // 사용자 보증금 (userAddress => CollateralStruct)
    mapping(address => Collateral) collateral;
    // 사용자 펀딩비 (userAddress => poolAddress => LiquidityProviderStructArray)
    mapping(address => mapping(address => LiquidityProvider)) public liquidityProviders;
    // 1LP당 거래수수료 보상 (poolAddress => Uint)
    mapping(address => uint256) public cumulativeTransactionFee;


    /// @inheritdoc IVault
    // 소수점 자리수 조회
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

// modifiers
    // 보증금으로 USDT를 넣는지 체크
    // ** _USDTaddr
    modifier onlyUSDTToken(address _addr) {
        require(_addr == _settlementToken, "V_IT");    // Invalid Token
        _;
    }

    // Clearing House에서만 실행 가능한 함수에 사용
    modifier onlyClearingHouse() {
        require(msg.sender == _clearingHouse, "V_CNAC");    // Caller is Not the Allowed Contract
        _;
    }

/// functions
// 초기 세팅
    function initialize() external initializer {
        _decimals = 18;
        _settlementToken = USDTaddress;
        // _insuranceFund = insuranceFundArg;
        // _clearingHouseConfig = clearingHouseConfigArg;
        // _accountBalance = accountBalanceArg;
        // _exchange = exchangeArg;        
    }

    // ClearingHouse 주소 설정
    function setClearingHouse(address clearingHouseAddr) external onlyOwner {
        require(clearingHouseAddr.isContract(), "V_CHNC");   // ClearingHouse is not contract

        _clearingHouse = clearingHouseAddr;
        emit ClearingHouseChanged(clearingHouseAddr);
    }

// 보증금 관리
    // 예치
    /// @inheritdoc IVault
    function deposit(uint256 amount) external override nonReentrant onlyUSDTToken {
        address from = _msgSender();
        address token = _settlementToken;
        _deposit(from, from, token, amount);
    }

    /// @inheritdoc IVault
    function depositFor(
        address to,
        uint256 amount
    ) external override nonReentrant onlyUSDTToken(token) {
        require(to != address(0), "V_DFZA");    // Deposit for zero address

        address from = _msgSender();
        address token = _settlementToken;
        _deposit(from, to, token, amount);
    }

    function _deposit(
        address from,   // deposit token from this address
        address to,     // deposit token to this address
        address token,  // the collateral token wish to deposit
        uint256 amount  // the amount of token to deposit
    ) internal {
        require(amount > 0, "V_ZA");    // Zero Amount
        _transferTokenIn(token, from, amount);  // 전송하고, 정확한 amount의 token이 이 컨트랙트로 전송되었는지 확인
        _modifyBalance(to, token, amount.toInt256());
        emit Deposited(token, to, amount);
    }

    function _transferTokenIn(
        address token,  // the collateral token needs to be transferred into vault
        address from,   // the address of account who owns the collateral token
        uint256 amount  // the amount of collateral token needs to be transferred
    ) internal {
        // check for deflationary tokens by assuring balances before and after transferring to be the same
        uint256 balanceBefore = IERC20Metadata(token).balanceOf(address(this)); // 이 컨트랙트에 존재하는 USDT 잔고
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), from, address(this), amount);
        require((IERC20Metadata(token).balanceOf(address(this)).sub(balanceBefore)) == amount, "V_IBA");    // inconsistent balance amount
    }

    // 인출
    /// @inheritdoc IVault
    // the full process of withdrawal:
    // 1. settle funding payment to owedRealizedPnl
    // 2. collect fee to owedRealizedPnl
    // 3. call Vault.withdraw(token, amount)
    // 4. settle pnl to trader balance in Vault
    // 5. transfer the amount to trader
    function withdraw(address token, uint256 amount)
        external
        override
        nonReentrant
        onlyUSDTToken(token)
    {
        address to = _msgSender();
        _withdraw(to, token, amount);
    }

    function _withdraw(
        address to,
        address token,
        uint256 amount
    ) internal {
        _settleAndDecreaseBalance(to, token, amount);
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(token), to, amount);
        emit Withdrawn(token, to, amount);
    }

    function _settleAndDecreaseBalance(
        address to,
        address token,
        uint256 amount
    ) internal {
        uint256 freeCollateral = collateral[to][token].totalCollateral - collateral[to][token].useCollateral;
        require(freeCollateral >= amount, "V_NEFC");    // not enough freeCollateral

        int256 deltaBalance = amount.toInt256().neg256();   // 음수 표현

        _modifyBalance(to, token, deltaBalance);
    }

    // Clearing House에서 Position Open, Close할 때 호출
    function updateCollateral(address _user, int112 _amount) public onlyClearingHouse {
        collateral[_user].totalCollateral += _amount;
    } 

    /// @param amount can be 0; do not require this
    function _modifyBalance(
        address trader,
        address token,
        int256 amount
    ) internal {
        if (amount == 0) {
            return;
        }

        int112 oldBalance = collateral[trader].totalCollateral;
        int112 newBalance = oldBalance.add(amount);
        collateral[trader].totalCollateral = newBalance;

        if (token == _settlementToken) {
            return;
        }
    }

    // 총 보증금 조회
    function getCollateral() external view returns(uint256) {
        return collateral[_msgSender()].totalCollateral.toUint256();
    }

    // 사용중인 보증금 조회
    function getUseCollateral() external view returns(uint256) {
        return collateral[_msgSender()].useCollateral.toUint256();
    }


// 수수료 관리
    // 보상 지급(Claim)
    function claimRewards(address poolAddr) external {
        address token = _settlementToken;
        uint112 amount = getCumulativeTransactionFee(poolAddr) * liquidityProviders[_msgSender()][poolAddr].userLP;
        // 보증금 업데이트
        collateral[trader].totalCollateral += amount;
        _deposit(from, from, token, amount);
    }

    // 1LP당 거래수수료 계산 (input-poolAddress, lpTokenAddress)
    function calculateCumulativeTransactionFee(address poolAddr, address lpToken) external {
        (uint112 reserve0, uint112 reserve1) = getPoolReserves(poolAddr);
        uint256 totalLPTokens = getTotalLPTokens(lpToken);

        require(totalLPTokens > 0, "V_ZLPT");    // Zerp LP token
        
        address token = _settlementToken;   // 보상을 계산할 토큰 주소, 거래 수수료로 쌓이는 토큰 = USDT
        address token0 = IUniswapV2Pair(poolAddr).token0();
        uint256 totalFees = token == token0 ? uint256(reserve0) : uint256(reserve1);
        
        rewardPerLP = totalFees / totalLPTokens;
        cumulativeTransactionFee[poolAddr] = rewardPerLP;
    }

    // 현재 풀에 쌓여있는 총 거래 수수료
    function getPoolReserves(address poolAddr) external view returns (uint112 reserveA, uint112 reserveB) {
        (uint reserveA, uint reserveB, ) = IUniswapV2Pair(poolAddr).getReserves();
    }

    // 현재 풀에 존재하는 총 LP 토큰 개수
    function getTotalLPTokens(address lpToken) external view returns (uint256) {
        IERC20 lpTokenContract = IERC20(lpToken);
        return lpTokenContract.totalSupply();
    }

    // Liquidity Pool 정보
    // function getLiquidityPoolInfo(address pair, address lpToken) external view returns (uint112 reserve0, uint112 reserve1, uint256 totalLPTokens) {
    //     (reserve0, reserve1) = getPoolReserves(pair);
    //     totalLPTokens = getTotalLPTokens(lpToken);
    // }

    // 1LP당 누적 거래 수수료 조회
    function getCumulativeTransactionFee(address pair) public returns(uint256) {
        return cumulativeTransactionFee[pair];
    }

    // pool에 거래 수수료 누적해주는 함수 - Clearing House만 호출할 수 있게 질문!!!!!
    // function setCumulativeTransactionFee(address poolAddr, uint256 fee) {
    //     cumulativeTransactionFee[pair] = 
    // }

}
