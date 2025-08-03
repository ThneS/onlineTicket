// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenSwap
 * @dev AMM自动做市商合约，实现平台代币与ETH的自动交换
 * @notice 基于恒定乘积公式 (x * y = k) 的AMM协议
 */
contract TokenSwap is ERC20, Ownable, ReentrancyGuard, Pausable {
    // ============ 状态变量 ============

    IERC20 public immutable platformToken;

    // 流动性池储备
    uint256 public reserveToken; // 平台代币储备
    uint256 public reserveETH; // ETH储备

    // 费率设置 (基点，即万分之几)
    uint256 public swapFeeRate = 30; // 0.3% 交换手续费
    uint256 public protocolFeeRate = 5; // 协议费率（从交换费中抽取）

    // 最小流动性（防止除零错误）
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    // 流动性提供相关
    mapping(address => uint256) public userLiquidity; // 用户流动性份额
    uint256 public totalLiquidity; // 总流动性份额

    // 价格预言机相关
    uint256 public lastUpdateTime;
    uint256 public tokenCumulativePrice; // 代币累积价格
    uint256 public ethCumulativePrice; // ETH累积价格

    // 收入统计
    uint256 public totalProtocolFeesToken; // 协议总手续费（平台代币）
    uint256 public totalProtocolFeesETH; // 协议总手续费（ETH）

    // 滑点保护
    uint256 public maxSlippageRate = 1000; // 最大滑点 10%（测试时更宽松）

    // ============ 事件 ============

    event LiquidityAdded(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event ReservesUpdated(uint256 reserveToken, uint256 reserveETH);

    event FeeRatesUpdated(uint256 swapFeeRate, uint256 protocolFeeRate);

    event PriceUpdated(uint256 tokenPrice, uint256 ethPrice, uint256 timestamp);

    // ============ 修饰符 ============

    modifier updateReserves() {
        _;
        _updateReserves();
        _updatePrice();
    }

    modifier validSlippage(uint256 expectedAmount, uint256 actualAmount) {
        uint256 slippage = expectedAmount > actualAmount
            ? ((expectedAmount - actualAmount) * 10000) / expectedAmount
            : 0;
        require(slippage <= maxSlippageRate, "TokenSwap: slippage too high");
        _;
    }

    // ============ 构造函数 ============

    constructor(
        address initialOwner,
        address _platformToken,
        string memory lpTokenName,
        string memory lpTokenSymbol
    ) ERC20(lpTokenName, lpTokenSymbol) Ownable(initialOwner) {
        require(
            _platformToken != address(0),
            "TokenSwap: invalid platform token"
        );

        platformToken = IERC20(_platformToken);
        lastUpdateTime = block.timestamp;
    }

    // ============ 流动性管理 ============

    /**
     * @dev 添加流动性
     */
    function addLiquidity(
        uint256 tokenAmount,
        uint256 minTokenAmount,
        uint256 minETHAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updateReserves
        returns (uint256 liquidity)
    {
        require(tokenAmount > 0 && msg.value > 0, "TokenSwap: invalid amounts");

        uint256 ethAmount = msg.value;

        if (totalSupply() == 0) {
            // 初始流动性提供
            liquidity = Math.sqrt(tokenAmount * ethAmount) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "TokenSwap: insufficient liquidity");

            // 锁定最小流动性到合约地址（防止流动性池被完全抽干）
            _mint(address(this), MINIMUM_LIQUIDITY);
        } else {
            // 计算基于当前比例的流动性
            uint256 liquidityToken = (tokenAmount * totalSupply()) /
                reserveToken;
            uint256 liquidityETH = (ethAmount * totalSupply()) / reserveETH;
            liquidity = Math.min(liquidityToken, liquidityETH);

            require(liquidity > 0, "TokenSwap: insufficient liquidity");

            // 调整实际存入金额以保持比例
            uint256 actualTokenAmount = (liquidity * reserveToken) /
                totalSupply();
            uint256 actualETHAmount = (liquidity * reserveETH) / totalSupply();

            require(
                actualTokenAmount >= minTokenAmount,
                "TokenSwap: insufficient token amount"
            );
            require(
                actualETHAmount >= minETHAmount,
                "TokenSwap: insufficient ETH amount"
            );

            // 退还多余的ETH
            if (ethAmount > actualETHAmount) {
                payable(msg.sender).transfer(ethAmount - actualETHAmount);
            }

            tokenAmount = actualTokenAmount;
            ethAmount = actualETHAmount;
        }

        // 转入代币
        require(
            platformToken.transferFrom(msg.sender, address(this), tokenAmount),
            "TokenSwap: token transfer failed"
        );

        // 铸造LP代币
        _mint(msg.sender, liquidity);

        // 更新用户流动性记录
        userLiquidity[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        emit LiquidityAdded(msg.sender, tokenAmount, ethAmount, liquidity);
    }

    /**
     * @dev 移除流动性
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minTokenAmount,
        uint256 minETHAmount
    )
        external
        nonReentrant
        updateReserves
        returns (uint256 tokenAmount, uint256 ethAmount)
    {
        require(liquidity > 0, "TokenSwap: invalid liquidity");
        require(
            balanceOf(msg.sender) >= liquidity,
            "TokenSwap: insufficient LP tokens"
        );

        uint256 totalSupplyLP = totalSupply();

        // 计算可获得的代币数量
        tokenAmount = (liquidity * reserveToken) / totalSupplyLP;
        ethAmount = (liquidity * reserveETH) / totalSupplyLP;

        require(
            tokenAmount >= minTokenAmount,
            "TokenSwap: insufficient token amount"
        );
        require(
            ethAmount >= minETHAmount,
            "TokenSwap: insufficient ETH amount"
        );

        // 销毁LP代币
        _burn(msg.sender, liquidity);

        // 转出代币和ETH
        require(
            platformToken.transfer(msg.sender, tokenAmount),
            "TokenSwap: token transfer failed"
        );
        payable(msg.sender).transfer(ethAmount);

        // 更新用户流动性记录
        userLiquidity[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        emit LiquidityRemoved(msg.sender, tokenAmount, ethAmount, liquidity);
    }

    // ============ 交换功能 ============

    /**
     * @dev 用ETH购买平台代币
     */
    function swapETHForTokens(
        uint256 minTokensOut
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updateReserves
        validSlippage(getTokenAmountOut(msg.value), minTokensOut)
    {
        require(msg.value > 0, "TokenSwap: invalid ETH amount");

        uint256 tokensOut = getTokenAmountOut(msg.value);
        require(
            tokensOut >= minTokensOut,
            "TokenSwap: insufficient output amount"
        );
        require(
            tokensOut <= reserveToken,
            "TokenSwap: insufficient token liquidity"
        );

        // 计算手续费
        uint256 fee = (msg.value * swapFeeRate) / 10000;
        uint256 protocolFee = (fee * protocolFeeRate) / 100;

        // 更新储备
        reserveETH += msg.value;
        reserveToken -= tokensOut;

        // 转出代币
        require(
            platformToken.transfer(msg.sender, tokensOut),
            "TokenSwap: token transfer failed"
        );

        // 记录协议费用
        totalProtocolFeesETH += protocolFee;

        emit Swap(
            msg.sender,
            address(0), // ETH
            address(platformToken),
            msg.value,
            tokensOut,
            fee
        );
    }

    /**
     * @dev 用平台代币购买ETH
     */
    function swapTokensForETH(
        uint256 tokenAmountIn,
        uint256 minETHOut
    )
        external
        nonReentrant
        whenNotPaused
        updateReserves
        validSlippage(getETHAmountOut(tokenAmountIn), minETHOut)
    {
        require(tokenAmountIn > 0, "TokenSwap: invalid token amount");

        uint256 ethOut = getETHAmountOut(tokenAmountIn);
        require(ethOut >= minETHOut, "TokenSwap: insufficient output amount");
        require(ethOut <= reserveETH, "TokenSwap: insufficient ETH liquidity");

        // 计算手续费
        uint256 fee = (tokenAmountIn * swapFeeRate) / 10000;
        uint256 protocolFee = (fee * protocolFeeRate) / 100;

        // 转入代币
        require(
            platformToken.transferFrom(
                msg.sender,
                address(this),
                tokenAmountIn
            ),
            "TokenSwap: token transfer failed"
        );

        // 更新储备
        reserveToken += tokenAmountIn;
        reserveETH -= ethOut;

        // 转出ETH
        payable(msg.sender).transfer(ethOut);

        // 记录协议费用
        totalProtocolFeesToken += protocolFee;

        emit Swap(
            msg.sender,
            address(platformToken),
            address(0), // ETH
            tokenAmountIn,
            ethOut,
            fee
        );
    }

    // ============ 价格查询 ============

    /**
     * @dev 获取用ETH购买代币的输出数量
     */
    function getTokenAmountOut(
        uint256 ethAmountIn
    ) public view returns (uint256) {
        require(ethAmountIn > 0, "TokenSwap: invalid input amount");
        require(
            reserveETH > 0 && reserveToken > 0,
            "TokenSwap: insufficient liquidity"
        );

        uint256 ethAmountInWithFee = ethAmountIn * (10000 - swapFeeRate);
        uint256 numerator = ethAmountInWithFee * reserveToken;
        uint256 denominator = (reserveETH * 10000) + ethAmountInWithFee;

        return numerator / denominator;
    }

    /**
     * @dev 获取用代币购买ETH的输出数量
     */
    function getETHAmountOut(
        uint256 tokenAmountIn
    ) public view returns (uint256) {
        require(tokenAmountIn > 0, "TokenSwap: invalid input amount");
        require(
            reserveETH > 0 && reserveToken > 0,
            "TokenSwap: insufficient liquidity"
        );

        uint256 tokenAmountInWithFee = tokenAmountIn * (10000 - swapFeeRate);
        uint256 numerator = tokenAmountInWithFee * reserveETH;
        uint256 denominator = (reserveToken * 10000) + tokenAmountInWithFee;

        return numerator / denominator;
    }

    /**
     * @dev 获取当前价格比率
     */
    function getPrice()
        external
        view
        returns (uint256 tokenPrice, uint256 ethPrice)
    {
        require(reserveETH > 0 && reserveToken > 0, "TokenSwap: no liquidity");

        // 价格以另一种资产计价
        tokenPrice = (reserveETH * 1e18) / reserveToken; // 1个代币值多少ETH
        ethPrice = (reserveToken * 1e18) / reserveETH; // 1个ETH值多少代币
    }

    /**
     * @dev 获取时间加权平均价格（TWAP）
     */
    function getTWAP(
        uint256 timeWindow
    ) external view returns (uint256 avgTokenPrice, uint256 avgETHPrice) {
        require(timeWindow > 0, "TokenSwap: invalid time window");
        require(
            block.timestamp > lastUpdateTime,
            "TokenSwap: no price updates"
        );

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed < timeWindow) {
            // 如果时间窗口内没有足够数据，返回当前价格
            return this.getPrice();
        }

        // 简化的TWAP计算（实际项目中需要更复杂的实现）
        avgTokenPrice = tokenCumulativePrice / timeElapsed;
        avgETHPrice = ethCumulativePrice / timeElapsed;
    }

    // ============ 内部函数 ============

    /**
     * @dev 更新储备量
     */
    function _updateReserves() internal {
        reserveToken =
            platformToken.balanceOf(address(this)) -
            totalProtocolFeesToken;
        reserveETH = address(this).balance - totalProtocolFeesETH;

        emit ReservesUpdated(reserveToken, reserveETH);
    }

    /**
     * @dev 更新累积价格
     */
    function _updatePrice() internal {
        if (reserveETH > 0 && reserveToken > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            if (timeElapsed > 0) {
                // 累积价格更新
                tokenCumulativePrice +=
                    ((reserveETH * 1e18) / reserveToken) *
                    timeElapsed;
                ethCumulativePrice +=
                    ((reserveToken * 1e18) / reserveETH) *
                    timeElapsed;
                lastUpdateTime = block.timestamp;

                emit PriceUpdated(
                    (reserveETH * 1e18) / reserveToken,
                    (reserveToken * 1e18) / reserveETH,
                    block.timestamp
                );
            }
        }
    }

    // ============ 高级交换功能 ============

    /**
     * @dev 批量交换（支持多步骤交换）
     */
    function multiSwap(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256 /* minAmountOut */
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 /* finalAmountOut */)
    {
        require(
            tokens.length == amounts.length,
            "TokenSwap: array length mismatch"
        );
        require(tokens.length >= 2, "TokenSwap: insufficient swap steps");

        // 这里可以实现多代币交换路径
        // 当前简化实现只支持代币<->ETH的直接交换
        revert("TokenSwap: multi-swap not implemented yet");
    }

    /**
     * @dev 闪电贷功能
     */
    function flashLoan(
        uint256 tokenAmount,
        uint256 ethAmount,
        bytes calldata data
    ) external nonReentrant {
        require(
            tokenAmount <= reserveToken || ethAmount <= reserveETH,
            "TokenSwap: insufficient reserves"
        );

        uint256 balanceTokenBefore = platformToken.balanceOf(address(this));
        uint256 balanceETHBefore = address(this).balance;

        // 发送代币/ETH给借款人
        if (tokenAmount > 0) {
            require(
                platformToken.transfer(msg.sender, tokenAmount),
                "TokenSwap: token transfer failed"
            );
        }
        if (ethAmount > 0) {
            payable(msg.sender).transfer(ethAmount);
        }

        // 调用借款人的回调函数
        IFlashLoanReceiver(msg.sender).onFlashLoan(
            tokenAmount,
            ethAmount,
            data
        );

        // 检查还款（包含手续费）
        uint256 feeToken = (tokenAmount * swapFeeRate) / 10000;
        uint256 feeETH = (ethAmount * swapFeeRate) / 10000;

        require(
            platformToken.balanceOf(address(this)) >=
                balanceTokenBefore + feeToken,
            "TokenSwap: flash loan not repaid"
        );
        require(
            address(this).balance >= balanceETHBefore + feeETH,
            "TokenSwap: flash loan not repaid"
        );

        // 更新协议费用
        totalProtocolFeesToken += (feeToken * protocolFeeRate) / 100;
        totalProtocolFeesETH += (feeETH * protocolFeeRate) / 100;
    }

    // ============ 管理功能 ============

    /**
     * @dev 设置交换费率
     */
    function setSwapFeeRate(uint256 newSwapFeeRate) external onlyOwner {
        require(newSwapFeeRate <= 1000, "TokenSwap: fee rate too high"); // 最大10%
        swapFeeRate = newSwapFeeRate;
        emit FeeRatesUpdated(swapFeeRate, protocolFeeRate);
    }

    /**
     * @dev 设置协议费率
     */
    function setProtocolFeeRate(uint256 newProtocolFeeRate) external onlyOwner {
        require(
            newProtocolFeeRate <= 50,
            "TokenSwap: protocol fee rate too high"
        ); // 最大50%
        protocolFeeRate = newProtocolFeeRate;
        emit FeeRatesUpdated(swapFeeRate, protocolFeeRate);
    }

    /**
     * @dev 设置最大滑点
     */
    function setMaxSlippageRate(uint256 newMaxSlippageRate) external onlyOwner {
        require(
            newMaxSlippageRate <= 2000,
            "TokenSwap: slippage rate too high"
        ); // 最大20%
        maxSlippageRate = newMaxSlippageRate;
    }

    /**
     * @dev 提取协议费用
     */
    function withdrawProtocolFees(
        bool isETH,
        uint256 amount
    ) external onlyOwner {
        if (isETH) {
            require(
                amount <= totalProtocolFeesETH,
                "TokenSwap: insufficient ETH fees"
            );
            totalProtocolFeesETH -= amount;
            payable(owner()).transfer(amount);
        } else {
            require(
                amount <= totalProtocolFeesToken,
                "TokenSwap: insufficient token fees"
            );
            totalProtocolFeesToken -= amount;
            require(
                platformToken.transfer(owner(), amount),
                "TokenSwap: token transfer failed"
            );
        }
    }

    /**
     * @dev 暂停/恢复合约
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev 紧急提取（仅限紧急情况）
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "TokenSwap: withdraw to zero address");

        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

    // ============ 查询功能 ============

    /**
     * @dev 获取用户LP代币余额和对应的资产价值
     */
    function getUserLiquidityInfo(
        address user
    )
        external
        view
        returns (
            uint256 lpBalance,
            uint256 tokenValue,
            uint256 ethValue,
            uint256 sharePercentage
        )
    {
        lpBalance = balanceOf(user);
        uint256 totalSupplyLP = totalSupply();

        if (totalSupplyLP > 0 && lpBalance > 0) {
            tokenValue = (lpBalance * reserveToken) / totalSupplyLP;
            ethValue = (lpBalance * reserveETH) / totalSupplyLP;
            sharePercentage = (lpBalance * 10000) / totalSupplyLP; // 以基点表示
        }
    }

    /**
     * @dev 获取流动性池统计信息
     */
    function getPoolStats()
        external
        view
        returns (
            uint256 totalValueLocked,
            uint256 volume24h,
            uint256 feesGenerated24h,
            uint256 apr
        )
    {
        // 计算总锁定价值（以ETH计价）
        totalValueLocked = reserveETH * 2; // 假设代币和ETH价值相等

        // 这里需要实现24小时统计逻辑
        // 简化返回，实际项目中需要复杂的统计系统
        volume24h = 0;
        feesGenerated24h = 0;
        apr = 0;
    }

    /**
     * @dev 估算添加流动性所需的金额
     */
    function calculateAddLiquidity(
        uint256 tokenAmount
    ) external view returns (uint256 requiredETH, uint256 lpTokensOut) {
        if (totalSupply() == 0) {
            // 初始流动性
            requiredETH = tokenAmount; // 1:1 比例
            lpTokensOut = Math.sqrt(tokenAmount * requiredETH);
        } else {
            // 按当前比例计算
            requiredETH = (tokenAmount * reserveETH) / reserveToken;
            lpTokensOut = (tokenAmount * totalSupply()) / reserveToken;
        }
    }

    /**
     * @dev 估算移除流动性可获得的金额
     */
    function calculateRemoveLiquidity(
        uint256 liquidity
    ) external view returns (uint256 tokenAmount, uint256 ethAmount) {
        uint256 totalSupplyLP = totalSupply();
        if (totalSupplyLP > 0) {
            tokenAmount = (liquidity * reserveToken) / totalSupplyLP;
            ethAmount = (liquidity * reserveETH) / totalSupplyLP;
        }
    }

    // ============ 接收ETH ============

    /**
     * @dev 接收ETH（用于流动性提供）
     */
    receive() external payable {
        // 可以添加额外的ETH接收逻辑
    }
}

/**
 * @title IFlashLoanReceiver
 * @dev 闪电贷接收者接口
 */
interface IFlashLoanReceiver {
    function onFlashLoan(
        uint256 tokenAmount,
        uint256 ethAmount,
        bytes calldata data
    ) external;
}
