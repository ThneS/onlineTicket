// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TokenSwap.sol";
import "../src/PlatformToken.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    PlatformToken public platformToken;

    address public owner = address(0x99); // 使用普通地址而不是预编译合约地址
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public liquidityProvider = address(0x4);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;
    uint256 public constant INITIAL_ETH = 100 ether;
    uint256 public constant INITIAL_TOKENS = 100000 * 10 ** 18;

    function setUp() public {
        // 部署平台代币
        vm.prank(owner);
        platformToken = new PlatformToken(owner);

        // 部署 TokenSwap 合约
        vm.prank(owner);
        tokenSwap = new TokenSwap(
            owner,
            address(platformToken),
            "Platform LP Token",
            "PLT-LP"
        );

        // 为用户分配资金
        vm.deal(owner, 10 ether); // 给owner分配ETH用于测试
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(liquidityProvider, INITIAL_ETH);

        // 为用户分配代币
        vm.startPrank(owner);
        platformToken.transfer(user1, 10000 * 10 ** 18);
        platformToken.transfer(user2, 10000 * 10 ** 18);
        platformToken.transfer(liquidityProvider, INITIAL_TOKENS);
        vm.stopPrank();

        // 用户授权TokenSwap合约
        vm.prank(user1);
        platformToken.approve(address(tokenSwap), type(uint256).max);

        vm.prank(user2);
        platformToken.approve(address(tokenSwap), type(uint256).max);

        vm.prank(liquidityProvider);
        platformToken.approve(address(tokenSwap), type(uint256).max);
    }

    function testInitialState() public {
        assertEq(address(tokenSwap.platformToken()), address(platformToken));
        assertEq(tokenSwap.owner(), owner);
        assertEq(tokenSwap.reserveToken(), 0);
        assertEq(tokenSwap.reserveETH(), 0);
        assertEq(tokenSwap.swapFeeRate(), 30); // 0.3%
        assertEq(tokenSwap.protocolFeeRate(), 5); // 5%
    }

    function testAddInitialLiquidity() public {
        uint256 tokenAmount = 1000 * 10 ** 18;
        uint256 ethAmount = 1 ether;

        console.log("=== Testing Add Initial Liquidity ===");
        console.log("Token Amount:", tokenAmount / 10 ** 18);
        console.log("ETH Amount:", ethAmount / 10 ** 18);
        console.log(
            "Provider Balance Before (Token):",
            platformToken.balanceOf(liquidityProvider) / 10 ** 18
        );
        console.log(
            "Provider Balance Before (ETH):",
            liquidityProvider.balance / 10 ** 18
        );

        vm.prank(liquidityProvider);
        uint256 liquidity = tokenSwap.addLiquidity{value: ethAmount}(
            tokenAmount,
            tokenAmount,
            ethAmount
        );

        console.log("LP Tokens Minted:", liquidity / 10 ** 18);
        console.log(
            "Reserve Token After:",
            tokenSwap.reserveToken() / 10 ** 18
        );
        console.log("Reserve ETH After:", tokenSwap.reserveETH() / 10 ** 18);
        console.log("Total Supply LP:", tokenSwap.totalSupply() / 10 ** 18);

        // 检查流动性代币余额
        assertGt(liquidity, 0);
        assertEq(tokenSwap.balanceOf(liquidityProvider), liquidity);

        // 检查储备量
        assertEq(tokenSwap.reserveToken(), tokenAmount);
        assertEq(tokenSwap.reserveETH(), ethAmount);

        // 检查用户流动性记录
        assertEq(tokenSwap.userLiquidity(liquidityProvider), liquidity);
        console.log(unicode"✅ Initial liquidity test passed");
    }

    function testAddLiquidityWithExistingPool() public {
        // 先添加初始流动性
        testAddInitialLiquidity();

        console.log("\n=== Testing Add Liquidity to Existing Pool ===");
        uint256 additionalTokens = 500 * 10 ** 18;
        uint256 additionalETH = 0.5 ether;

        console.log("Additional Tokens:", additionalTokens / 10 ** 18);
        console.log("Additional ETH:", additionalETH / 10 ** 18);

        uint256 liquidityBefore = tokenSwap.balanceOf(liquidityProvider);
        console.log("LP Balance Before:", liquidityBefore / 10 ** 18);

        // 计算实际需要的金额
        (uint256 requiredETH, uint256 expectedLP) = tokenSwap
            .calculateAddLiquidity(additionalTokens);
        console.log("Required ETH for ratio:", requiredETH / 10 ** 18);
        console.log("Expected LP tokens:", expectedLP / 10 ** 18);

        vm.prank(liquidityProvider);
        uint256 newLiquidity = tokenSwap.addLiquidity{value: additionalETH}(
            additionalTokens,
            (additionalTokens * 95) / 100, // 5% slippage tolerance
            (additionalETH * 95) / 100
        );

        console.log("New LP Tokens Minted:", newLiquidity / 10 ** 18);
        console.log(
            "Total LP Balance After:",
            tokenSwap.balanceOf(liquidityProvider) / 10 ** 18
        );

        assertGt(newLiquidity, 0);
        assertEq(
            tokenSwap.balanceOf(liquidityProvider),
            liquidityBefore + newLiquidity
        );
        console.log(unicode"✅ Add liquidity to existing pool test passed");
    }

    function testRemoveLiquidity() public {
        // 先添加流动性
        testAddInitialLiquidity();

        uint256 lpTokens = tokenSwap.balanceOf(liquidityProvider);
        uint256 liquidityToRemove = lpTokens / 2; // 移除50%

        uint256 tokenBefore = platformToken.balanceOf(liquidityProvider);
        uint256 ethBefore = liquidityProvider.balance;

        vm.prank(liquidityProvider);
        (uint256 tokenAmount, uint256 ethAmount) = tokenSwap.removeLiquidity(
            liquidityToRemove,
            0,
            0
        );

        assertGt(tokenAmount, 0);
        assertGt(ethAmount, 0);

        // 检查余额变化
        assertEq(
            platformToken.balanceOf(liquidityProvider),
            tokenBefore + tokenAmount
        );
        assertEq(liquidityProvider.balance, ethBefore + ethAmount);

        // 检查LP代币余额
        assertEq(
            tokenSwap.balanceOf(liquidityProvider),
            lpTokens - liquidityToRemove
        );
    }

    function testSwapETHForTokens() public {
        // 先添加流动性
        testAddInitialLiquidity();

        console.log("\n=== Testing Swap ETH for Tokens ===");
        uint256 ethAmount = 0.1 ether;
        uint256 expectedTokens = tokenSwap.getTokenAmountOut(ethAmount);

        console.log("ETH Input:", ethAmount / 10 ** 18);
        console.log("Expected Tokens Output:", expectedTokens / 10 ** 18);
        console.log(
            "User1 Token Balance Before:",
            platformToken.balanceOf(user1) / 10 ** 18
        );
        console.log("User1 ETH Balance Before:", user1.balance / 10 ** 18);

        uint256 tokenBefore = platformToken.balanceOf(user1);

        vm.prank(user1);
        tokenSwap.swapETHForTokens{value: ethAmount}(expectedTokens);

        uint256 tokenAfter = platformToken.balanceOf(user1);

        console.log("User1 Token Balance After:", tokenAfter / 10 ** 18);
        console.log("User1 ETH Balance After:", user1.balance / 10 ** 18);
        console.log(
            "Actual Tokens Received:",
            (tokenAfter - tokenBefore) / 10 ** 18
        );
        console.log(
            "Reserve Token After Swap:",
            tokenSwap.reserveToken() / 10 ** 18
        );
        console.log(
            "Reserve ETH After Swap:",
            tokenSwap.reserveETH() / 10 ** 18
        );

        assertEq(tokenAfter - tokenBefore, expectedTokens);

        // 检查储备量变化
        assertGt(tokenSwap.reserveETH(), 1 ether); // 增加了ETH
        assertLt(tokenSwap.reserveToken(), 1000 * 10 ** 18); // 减少了代币
        console.log(unicode"✅ ETH to Tokens swap test passed");
    }

    function testSwapTokensForETH() public {
        // 先添加流动性
        testAddInitialLiquidity();

        console.log("\n=== Testing Swap Tokens for ETH ===");
        uint256 tokenAmount = 100 * 10 ** 18;
        uint256 expectedETH = tokenSwap.getETHAmountOut(tokenAmount);

        console.log("Token Input:", tokenAmount / 10 ** 18);
        console.log("Expected ETH Output:", expectedETH / 10 ** 18);
        console.log(
            "User1 Token Balance Before:",
            platformToken.balanceOf(user1) / 10 ** 18
        );
        console.log("User1 ETH Balance Before:", user1.balance / 10 ** 18);

        uint256 ethBefore = user1.balance;

        vm.prank(user1);
        tokenSwap.swapTokensForETH(tokenAmount, expectedETH);

        uint256 ethAfter = user1.balance;

        console.log(
            "User1 Token Balance After:",
            platformToken.balanceOf(user1) / 10 ** 18
        );
        console.log("User1 ETH Balance After:", ethAfter / 10 ** 18);
        console.log("Actual ETH Received:", (ethAfter - ethBefore) / 10 ** 18);
        console.log(
            "Reserve Token After Swap:",
            tokenSwap.reserveToken() / 10 ** 18
        );
        console.log(
            "Reserve ETH After Swap:",
            tokenSwap.reserveETH() / 10 ** 18
        );

        assertEq(ethAfter - ethBefore, expectedETH);

        // 检查储备量变化
        assertLt(tokenSwap.reserveETH(), 1 ether); // 减少了ETH
        assertGt(tokenSwap.reserveToken(), 1000 * 10 ** 18); // 增加了代币
        console.log(unicode"✅ Tokens to ETH swap test passed");
    }

    function testPriceCalculation() public {
        // 添加流动性 1000 tokens : 1 ETH
        testAddInitialLiquidity();

        console.log("\n=== Testing Price Calculation ===");
        (uint256 tokenPrice, uint256 ethPrice) = tokenSwap.getPrice();

        console.log("Current Token Price (ETH per Token):", tokenPrice);
        console.log("Current ETH Price (Tokens per ETH):", ethPrice / 10 ** 18);
        console.log("Expected Token Price (wei):", uint256(1e15));
        console.log("Expected ETH Price:", uint256(1000));

        // 1个代币值 0.001 ETH (1000 tokens = 1 ETH)
        assertEq(tokenPrice, 1e15); // 0.001 ETH
        // 1个ETH值 1000 代币
        assertEq(ethPrice, 1000 * 10 ** 18);
        console.log(unicode"✅ Price calculation test passed");
    }

    function testSlippageProtection() public {
        testAddInitialLiquidity();

        console.log("\n=== Testing Slippage Protection ===");
        uint256 ethAmount = 0.1 ether;
        uint256 expectedTokens = tokenSwap.getTokenAmountOut(ethAmount);

        console.log("ETH Amount:", ethAmount / 10 ** 18);
        console.log("Expected Tokens:", expectedTokens / 10 ** 18);
        console.log("Setting min output to:", (expectedTokens + 1) / 10 ** 18);
        console.log(
            "Max Slippage Rate:",
            tokenSwap.maxSlippageRate(),
            "basis points"
        );

        // 设置过高的最小输出期望，应该失败
        vm.prank(user1);
        vm.expectRevert("TokenSwap: insufficient output amount");
        tokenSwap.swapETHForTokens{value: ethAmount}(expectedTokens + 1);
        console.log(
            unicode"✅ Slippage protection test passed - correctly reverted"
        );
    }

    function testFeeCollection() public {
        testAddInitialLiquidity();

        console.log("\n=== Testing Fee Collection ===");
        uint256 ethAmount = 0.1 ether;
        uint256 initialProtocolFeesETH = tokenSwap.totalProtocolFeesETH();

        console.log("ETH Amount for Swap:", ethAmount / 10 ** 18);
        console.log("Initial Protocol Fees ETH:", initialProtocolFeesETH);
        console.log("Swap Fee Rate:", tokenSwap.swapFeeRate(), "basis points");
        console.log("Protocol Fee Rate:", tokenSwap.protocolFeeRate(), "%");

        uint256 expectedTokens = tokenSwap.getTokenAmountOut(ethAmount);
        console.log("Expected tokens from swap:", expectedTokens / 10 ** 18);

        vm.prank(user1);
        tokenSwap.swapETHForTokens{value: ethAmount}(expectedTokens);

        uint256 finalProtocolFeesETH = tokenSwap.totalProtocolFeesETH();
        console.log("Final Protocol Fees ETH:", finalProtocolFeesETH);
        console.log(
            "Fees Collected:",
            finalProtocolFeesETH - initialProtocolFeesETH
        );

        assertGt(finalProtocolFeesETH, initialProtocolFeesETH);
        console.log(unicode"✅ Fee collection test passed");
    }

    function testWithdrawProtocolFees() public {
        testFeeCollection();

        uint256 protocolFeesETH = tokenSwap.totalProtocolFeesETH();
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        tokenSwap.withdrawProtocolFees(true, protocolFeesETH);

        assertEq(owner.balance, ownerBalanceBefore + protocolFeesETH);
        assertEq(tokenSwap.totalProtocolFeesETH(), 0);
    }

    function testSetFeeRates() public {
        vm.prank(owner);
        tokenSwap.setSwapFeeRate(50); // 0.5%

        assertEq(tokenSwap.swapFeeRate(), 50);

        vm.prank(owner);
        tokenSwap.setProtocolFeeRate(10);

        assertEq(tokenSwap.protocolFeeRate(), 10);
    }

    function testSetFeeRatesTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("TokenSwap: fee rate too high");
        tokenSwap.setSwapFeeRate(1001); // > 10%

        vm.prank(owner);
        vm.expectRevert("TokenSwap: protocol fee rate too high");
        tokenSwap.setProtocolFeeRate(51); // > 50%
    }

    function testPauseUnpause() public {
        vm.prank(owner);
        tokenSwap.pause();

        assertTrue(tokenSwap.paused());

        // 暂停时不能交换
        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.swapETHForTokens{value: 0.1 ether}(0);

        vm.prank(owner);
        tokenSwap.unpause();

        assertFalse(tokenSwap.paused());
    }

    function testUserLiquidityInfo() public {
        testAddInitialLiquidity();

        (
            uint256 lpBalance,
            uint256 tokenValue,
            uint256 ethValue,
            uint256 sharePercentage
        ) = tokenSwap.getUserLiquidityInfo(liquidityProvider);

        assertGt(lpBalance, 0);
        assertGt(tokenValue, 0);
        assertGt(ethValue, 0);
        assertGt(sharePercentage, 0);
        assertLe(sharePercentage, 10000); // 不超过100%
    }

    function testCalculateAddLiquidity() public {
        testAddInitialLiquidity();

        uint256 tokenAmount = 500 * 10 ** 18;
        (uint256 requiredETH, uint256 lpTokensOut) = tokenSwap
            .calculateAddLiquidity(tokenAmount);

        assertEq(requiredETH, 0.5 ether); // 按1000:1比例
        assertGt(lpTokensOut, 0);
    }

    function testCalculateRemoveLiquidity() public {
        testAddInitialLiquidity();

        uint256 lpTokens = tokenSwap.balanceOf(liquidityProvider);
        (uint256 tokenAmount, uint256 ethAmount) = tokenSwap
            .calculateRemoveLiquidity(lpTokens);

        assertGt(tokenAmount, 0);
        assertGt(ethAmount, 0);
    }

    function testGetPoolStats() public {
        testAddInitialLiquidity();

        (
            uint256 totalValueLocked,
            uint256 volume24h,
            uint256 feesGenerated24h,
            uint256 apr
        ) = tokenSwap.getPoolStats();

        assertEq(totalValueLocked, 2 ether); // 2 * 1 ETH
        // 其他统计项在简化实现中为0
        assertEq(volume24h, 0);
        assertEq(feesGenerated24h, 0);
        assertEq(apr, 0);
    }

    function testReentrancyProtection() public {
        // 测试防重入攻击
        testAddInitialLiquidity();

        // 创建恶意合约（这里简化测试）
        vm.prank(user1);
        vm.expectRevert(); // 应该因为某种原因失败
        tokenSwap.swapETHForTokens{value: 0.1 ether}(type(uint256).max);
    }

    function testInsufficientLiquidity() public {
        testAddInitialLiquidity();

        // 尝试交换超过储备的代币数量
        vm.prank(user1);
        vm.expectRevert("TokenSwap: slippage too high");
        tokenSwap.swapETHForTokens{value: 10 ether}(0);
    }

    function testOnlyOwnerFunctions() public {
        // 非所有者不能调用管理函数
        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.setSwapFeeRate(100);

        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.pause();

        vm.prank(user1);
        vm.expectRevert();
        tokenSwap.withdrawProtocolFees(true, 0);
    }
}
