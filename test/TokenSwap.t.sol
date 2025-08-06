// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";
import "../src/PlatformToken.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    PlatformToken public platformToken;

    address public owner;
    address public user1;
    address public user2;

    // 测试常量
    uint256 constant INITIAL_TOKEN_AMOUNT = 1000 * 1e18;
    uint256 constant INITIAL_ETH_AMOUNT = 10 ether;
    uint256 constant SMALL_TOKEN_AMOUNT = 100 * 1e18;
    uint256 constant SMALL_ETH_AMOUNT = 1 ether;

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

    function setUp() public {
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);

        // 设置测试账户余额
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // 部署PlatformToken
        vm.prank(owner);
        platformToken = new PlatformToken(owner);

        // 部署TokenSwap
        vm.prank(owner);
        tokenSwap = new TokenSwap(
            owner,
            address(platformToken),
            "LP Token",
            "LP"
        );

        // 给测试用户分发平台代币
        vm.startPrank(owner);
        platformToken.mint(user1, 10000 * 1e18);
        platformToken.mint(user2, 10000 * 1e18);
        platformToken.mint(owner, 10000 * 1e18);
        vm.stopPrank();
    }

    // ============ 部署和初始化测试 ============

    function test_Deployment() public {
        assertEq(address(tokenSwap.platformToken()), address(platformToken));
        assertEq(tokenSwap.owner(), owner);
        assertEq(tokenSwap.swapFeeRate(), 30); // 0.3%
        assertEq(tokenSwap.protocolFeeRate(), 5);
        assertEq(tokenSwap.maxSlippageRate(), 1000); // 10%
        assertEq(tokenSwap.reserveToken(), 0);
        assertEq(tokenSwap.reserveETH(), 0);
        assertEq(tokenSwap.totalSupply(), 0);
    }

    function test_InitialState() public {
        assertFalse(tokenSwap.paused());
        assertEq(tokenSwap.totalProtocolFeesToken(), 0);
        assertEq(tokenSwap.totalProtocolFeesETH(), 0);
        assertEq(tokenSwap.name(), "LP Token");
        assertEq(tokenSwap.symbol(), "LP");
    }

    // ============ 流动性管理测试 ============

    function test_AddLiquidity_FirstTime() public {
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);

        // 不检查具体的liquidity值，因为它是计算得出的
        vm.expectEmit(true, false, false, false);
        emit LiquidityAdded(user1, INITIAL_TOKEN_AMOUNT, INITIAL_ETH_AMOUNT, 0);

        uint256 liquidity = tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );

        assertGt(liquidity, 0);
        assertEq(tokenSwap.balanceOf(user1), liquidity);
        assertEq(tokenSwap.reserveToken(), INITIAL_TOKEN_AMOUNT);
        assertEq(tokenSwap.reserveETH(), INITIAL_ETH_AMOUNT);
        vm.stopPrank();
    }

    function test_AddLiquidity_SubsequentTime() public {
        // 首先添加初始流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        // 第二次添加流动性
        vm.startPrank(user2);
        platformToken.approve(address(tokenSwap), SMALL_TOKEN_AMOUNT);

        uint256 liquidity = tokenSwap.addLiquidity{value: SMALL_ETH_AMOUNT}(
            SMALL_TOKEN_AMOUNT,
            SMALL_TOKEN_AMOUNT,
            SMALL_ETH_AMOUNT
        );

        assertGt(liquidity, 0);
        assertGt(tokenSwap.balanceOf(user2), 0);
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        uint256 liquidity = tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );

        uint256 lpBalance = tokenSwap.balanceOf(user1);
        uint256 removeAmount = lpBalance / 2;

        uint256 ethBefore = user1.balance;
        uint256 tokenBefore = platformToken.balanceOf(user1);

        (uint256 tokenAmount, uint256 ethAmount) = tokenSwap.removeLiquidity(
            removeAmount,
            0,
            0
        );

        assertGt(tokenAmount, 0);
        assertGt(ethAmount, 0);
        assertGt(user1.balance, ethBefore);
        assertGt(platformToken.balanceOf(user1), tokenBefore);
        assertEq(tokenSwap.balanceOf(user1), lpBalance - removeAmount);
        vm.stopPrank();
    }

    // ============ 交换功能测试 ============

    function test_SwapETHForTokens() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        // 用户2用ETH购买代币
        vm.startPrank(user2);
        uint256 ethAmount = 1 ether;
        uint256 expectedTokens = tokenSwap.getTokenAmountOut(ethAmount);
        uint256 minTokensOut = (expectedTokens * 95) / 100; // 5%滑点容忍
        uint256 tokenBefore = platformToken.balanceOf(user2);

        tokenSwap.swapETHForTokens{value: ethAmount}(minTokensOut);

        uint256 tokenAfter = platformToken.balanceOf(user2);
        assertGt(tokenAfter, tokenBefore);
        assertApproxEqRel(tokenAfter - tokenBefore, expectedTokens, 1e15); // 0.1% 误差
        vm.stopPrank();
    }

    function test_SwapTokensForETH() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        // 用户2用代币购买ETH
        vm.startPrank(user2);
        uint256 tokenAmount = 100 * 1e18;
        uint256 expectedETH = tokenSwap.getETHAmountOut(tokenAmount);
        uint256 minETHOut = (expectedETH * 95) / 100; // 5%滑点容忍
        uint256 ethBefore = user2.balance;

        platformToken.approve(address(tokenSwap), tokenAmount);

        tokenSwap.swapTokensForETH(tokenAmount, minETHOut);

        uint256 ethAfter = user2.balance;
        assertGt(ethAfter, ethBefore);
        assertApproxEqRel(ethAfter - ethBefore, expectedETH, 1e15); // 0.1% 误差
        vm.stopPrank();
    }

    // ============ 价格查询测试 ============

    function test_GetTokenAmountOut() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        uint256 ethIn = 1 ether;
        uint256 tokensOut = tokenSwap.getTokenAmountOut(ethIn);

        assertGt(tokensOut, 0);
        assertLt(tokensOut, INITIAL_TOKEN_AMOUNT);
    }

    function test_GetETHAmountOut() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        uint256 tokensIn = 100 * 1e18;
        uint256 ethOut = tokenSwap.getETHAmountOut(tokensIn);

        assertGt(ethOut, 0);
        assertLt(ethOut, INITIAL_ETH_AMOUNT);
    }

    function test_GetPrice() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        (uint256 tokenPrice, uint256 ethPrice) = tokenSwap.getPrice();

        assertGt(tokenPrice, 0);
        assertGt(ethPrice, 0);

        // 验证价格关系：tokenPrice * ethPrice 应该接近 1e36
        uint256 product = (tokenPrice * ethPrice) / 1e18;
        assertApproxEqRel(product, 1e18, 1e15); // 0.1% 误差
    }

    // ============ 管理功能测试 ============

    function test_SetSwapFeeRate() public {
        uint256 newFeeRate = 50; // 0.5%

        vm.prank(owner);
        tokenSwap.setSwapFeeRate(newFeeRate);

        assertEq(tokenSwap.swapFeeRate(), newFeeRate);
    }

    function test_SetProtocolFeeRate() public {
        uint256 newProtocolFeeRate = 10; // 10%

        vm.prank(owner);
        tokenSwap.setProtocolFeeRate(newProtocolFeeRate);

        assertEq(tokenSwap.protocolFeeRate(), newProtocolFeeRate);
    }

    function test_Pause() public {
        vm.prank(owner);
        tokenSwap.pause();

        assertTrue(tokenSwap.paused());

        // 测试暂停后不能添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);

        vm.expectRevert("EnforcedPause()");
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();
    }

    function test_Unpause() public {
        vm.prank(owner);
        tokenSwap.pause();

        vm.prank(owner);
        tokenSwap.unpause();

        assertFalse(tokenSwap.paused());
    }

    // ============ 查询功能测试 ============

    function test_GetUserLiquidityInfo() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        uint256 liquidity = tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        (
            uint256 lpBalance,
            uint256 tokenValue,
            uint256 ethValue,
            uint256 sharePercentage
        ) = tokenSwap.getUserLiquidityInfo(user1);

        assertEq(lpBalance, tokenSwap.balanceOf(user1));
        assertGt(tokenValue, 0);
        assertGt(ethValue, 0);
        assertGt(sharePercentage, 0);
    }

    function test_CalculateAddLiquidity() public {
        uint256 tokenAmount = 1000 * 1e18;

        // 第一次添加流动性（池子为空）
        (uint256 requiredETH, uint256 lpTokensOut) = tokenSwap
            .calculateAddLiquidity(tokenAmount);

        assertEq(requiredETH, tokenAmount); // 1:1 比例
        assertGt(lpTokensOut, 0);
    }

    function test_CalculateRemoveLiquidity() public {
        // 先添加流动性
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);
        uint256 liquidity = tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(
            INITIAL_TOKEN_AMOUNT,
            INITIAL_TOKEN_AMOUNT,
            INITIAL_ETH_AMOUNT
        );
        vm.stopPrank();

        uint256 removeAmount = liquidity / 2;
        (uint256 tokenAmount, uint256 ethAmount) = tokenSwap
            .calculateRemoveLiquidity(removeAmount);

        assertGt(tokenAmount, 0);
        assertGt(ethAmount, 0);
        assertLt(tokenAmount, INITIAL_TOKEN_AMOUNT);
        assertLt(ethAmount, INITIAL_ETH_AMOUNT);
    }

    // ============ 错误处理测试 ============

    function test_RevertInvalidAmounts() public {
        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), INITIAL_TOKEN_AMOUNT);

        // 代币数量为0
        vm.expectRevert("TokenSwap: invalid amounts");
        tokenSwap.addLiquidity{value: INITIAL_ETH_AMOUNT}(0, 0, 0);

        // ETH数量为0
        vm.expectRevert("TokenSwap: invalid amounts");
        tokenSwap.addLiquidity{value: 0}(INITIAL_TOKEN_AMOUNT, 0, 0);
        vm.stopPrank();
    }

    function test_RevertInsufficientLiquidity() public {
        // 没有流动性时查询价格
        vm.expectRevert("TokenSwap: insufficient liquidity");
        tokenSwap.getTokenAmountOut(1 ether);

        vm.expectRevert("TokenSwap: insufficient liquidity");
        tokenSwap.getETHAmountOut(100 * 1e18);
    }

    function test_RevertUnauthorizedAccess() public {
        // 非owner设置费率
        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.setSwapFeeRate(100);

        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.setProtocolFeeRate(10);

        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.pause();
    }

    function test_RevertHighFeeRate() public {
        // 设置过高的交换费率
        vm.prank(owner);
        vm.expectRevert("TokenSwap: fee rate too high");
        tokenSwap.setSwapFeeRate(1001); // 超过10%

        // 设置过高的协议费率
        vm.prank(owner);
        vm.expectRevert("TokenSwap: protocol fee rate too high");
        tokenSwap.setProtocolFeeRate(51); // 超过50%
    }

    // ============ 边界测试 ============

    function test_MinimumLiquidity() public {
        vm.startPrank(user1);
        uint256 tokenAmount = 100000; // 更大的数量
        uint256 ethAmount = 100000;

        platformToken.approve(address(tokenSwap), tokenAmount);

        uint256 liquidity = tokenSwap.addLiquidity{value: ethAmount}(
            tokenAmount,
            tokenAmount,
            ethAmount
        );

        // 最小流动性应该被锁定到合约地址
        assertEq(
            tokenSwap.balanceOf(address(tokenSwap)),
            tokenSwap.MINIMUM_LIQUIDITY()
        );
        assertGt(liquidity, 0);
        vm.stopPrank();
    }
}
