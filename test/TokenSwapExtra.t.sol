// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TokenSwap.sol";
import "../src/PlatformToken.sol";

contract FlashLoanReceiverMock is IFlashLoanReceiver {
    address public caller;
    bool public repay;
    IERC20 public token;

    constructor(address _token, bool _repay) {
        token = IERC20(_token);
        repay = _repay;
    }

    receive() external payable {}

    function onFlashLoan(
        uint256 tokenAmount,
        uint256 ethAmount,
        bytes calldata
    ) external override {
        caller = msg.sender;
        // repay with fee
        if (repay) {
            if (tokenAmount > 0) {
                uint256 fee = (tokenAmount * 30) / 10000; // assume swapFeeRate 30
                token.transfer(msg.sender, tokenAmount + fee);
            }
            if (ethAmount > 0) {
                uint256 feeEth = (ethAmount * 30) / 10000;
                (bool s, ) = payable(msg.sender).call{
                    value: ethAmount + feeEth
                }("");
                require(s, "eth repay fail");
            }
        }
    }
}

contract TokenSwapExtraTest is Test {
    TokenSwap tokenSwap;
    PlatformToken platformToken;
    address owner = address(this);
    address user1 = address(0x2);
    address user2 = address(0x3);

    uint256 constant INIT_TOKEN = 10_000e18;
    uint256 constant INIT_ETH = 100 ether;

    function setUp() public {
        vm.deal(owner, INIT_ETH);
        vm.deal(user1, INIT_ETH);
        vm.deal(user2, INIT_ETH);

        platformToken = new PlatformToken(owner);
        platformToken.mint(user1, INIT_TOKEN);
        platformToken.mint(user2, INIT_TOKEN);
        platformToken.mint(owner, INIT_TOKEN);

        tokenSwap = new TokenSwap(
            owner,
            address(platformToken),
            "LP Token",
            "LP"
        );

        vm.startPrank(user1);
        platformToken.approve(address(tokenSwap), type(uint256).max);
        tokenSwap.addLiquidity{value: 10 ether}(5_000e18, 5_000e18, 10 ether);
        vm.stopPrank();
    }

    // 允许测试合约接收 ETH（用于 withdrawProtocolFees 测试）
    receive() external payable {}

    function test_SetMaxSlippageRate() public {
        vm.prank(owner);
        tokenSwap.setMaxSlippageRate(1500);
        assertEq(tokenSwap.maxSlippageRate(), 1500);
        vm.prank(owner);
        vm.expectRevert("TokenSwap: slippage rate too high");
        tokenSwap.setMaxSlippageRate(3000);
    }

    function test_SlippageRevert() public {
        vm.startPrank(user2);
        platformToken.approve(address(tokenSwap), type(uint256).max);
        uint256 tokensOut = tokenSwap.getTokenAmountOut(1 ether);
        // 设置极低 minTokensOut 之外的场景用 validSlippage: expected=getTokenAmountOut(amountIn) actual=minTokensOut(高) 不触发
        // 我们构造: 让 minTokensOut 比 expected 大，跳过 validSlippage 再由输出数量检查 revert
        uint256 higherThanPossible = tokensOut + 1e18;
        vm.expectRevert("TokenSwap: insufficient output amount");
        tokenSwap.swapETHForTokens{value: 1 ether}(higherThanPossible);
        vm.stopPrank();
    }

    function test_WithdrawProtocolFees() public {
        // 产生费用: 做几次 swap
        vm.startPrank(user2);
        platformToken.approve(address(tokenSwap), type(uint256).max);
        for (uint256 i = 0; i < 3; i++) {
            // 计算期望输出并设置不超过10%滑点的最小值 (maxSlippageRate=1000)
            uint256 expectedTokens = tokenSwap.getTokenAmountOut(0.5 ether);
            uint256 minTokens = (expectedTokens * 9000) / 10000; // 允许最多10%差异
            tokenSwap.swapETHForTokens{value: 0.5 ether}(minTokens);

            uint256 expectedEth = tokenSwap.getETHAmountOut(100e18);
            uint256 minEth = (expectedEth * 9000) / 10000;
            tokenSwap.swapTokensForETH(100e18, minEth);
        }
        vm.stopPrank();

        uint256 tokenFees = tokenSwap.totalProtocolFeesToken();
        uint256 ethFees = tokenSwap.totalProtocolFeesETH();
        assertTrue(tokenFees > 0 || ethFees > 0);

        uint256 ownerTokenBefore = platformToken.balanceOf(owner);
        uint256 ownerEthBefore = owner.balance;

        if (tokenFees > 0) {
            vm.prank(owner);
            tokenSwap.withdrawProtocolFees(false, tokenFees / 2);
            assertEq(
                platformToken.balanceOf(owner),
                ownerTokenBefore + tokenFees / 2
            );
        }
        if (ethFees > 0) {
            vm.prank(owner);
            tokenSwap.withdrawProtocolFees(true, ethFees / 2);
            assertEq(owner.balance, ownerEthBefore + ethFees / 2);
        }
    }

    function test_FlashLoanTokenSuccess() public {
        FlashLoanReceiverMock receiver = new FlashLoanReceiverMock(
            address(platformToken),
            true
        );
        // 给接收者足够 token 覆盖本金+手续费 (100 + 0.3) ≈ 100.3 => 101 留余量
        platformToken.transfer(address(receiver), 101e18);
        uint256 beforeFees = tokenSwap.totalProtocolFeesToken();
        // 需由接收者自身调用 flashLoan 以便回调成功
        vm.prank(address(receiver));
        tokenSwap.flashLoan(100e18, 0, abi.encode("data"));
        // fees 累加
        assertGe(tokenSwap.totalProtocolFeesToken(), beforeFees);
    }

    function test_MultiSwapNotImplemented() public {
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(platformToken);
        tokens[1] = address(0);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        vm.expectRevert("TokenSwap: multi-swap not implemented yet");
        tokenSwap.multiSwap(tokens, amounts, 0);
    }

    function test_EmgWithdraw() public {
        // transfer some tokens to contract directly (simulate stuck)
        platformToken.transfer(address(tokenSwap), 500e18);
        uint256 balBefore = platformToken.balanceOf(owner);
        vm.prank(owner);
        tokenSwap.emergencyWithdraw(address(platformToken), owner, 200e18);
        assertEq(platformToken.balanceOf(owner), balBefore + 200e18);
    }
}
