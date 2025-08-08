// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/PlatformToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PlatformTokenTest is Test {
    PlatformToken public token;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // 常量
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant INITIAL_SUPPLY = MAX_SUPPLY / 10;

    // 事件定义
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyWithdraw(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.prank(owner);
        token = new PlatformToken(owner);
    }

    // ================== 部署测试 ==================
    function test_Deploy() public view {
        assertEq(token.name(), "OnlineTicket Token");
        assertEq(token.symbol(), "OTT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
        assertEq(token.MAX_SUPPLY(), MAX_SUPPLY);
    }

    function test_InitialSupplyMinted() public {
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(owner, INITIAL_SUPPLY);

        vm.prank(owner);
        PlatformToken newToken = new PlatformToken(owner);

        assertEq(newToken.balanceOf(owner), INITIAL_SUPPLY);
    }

    // ================== Mint 功能测试 ==================
    function test_Mint() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        vm.expectEmit(true, false, false, true);
        emit TokensMinted(user1, mintAmount);

        vm.prank(owner);
        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function test_MintOnlyOwner() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, mintAmount);
    }

    function test_MintToZeroAddress() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: mint to zero address");
        token.mint(address(0), mintAmount);
    }

    function test_MintExceedsMaxSupply() public {
        uint256 exceedAmount = MAX_SUPPLY - token.totalSupply() + 1;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: exceeds max supply");
        token.mint(user1, exceedAmount);
    }

    function test_RemainMintableSupply() public {
        assertEq(token.remainMintableSupply(), MAX_SUPPLY - INITIAL_SUPPLY);

        uint256 mintAmount = 1000 * 10 ** 18;
        vm.prank(owner);
        token.mint(user1, mintAmount);

        assertEq(
            token.remainMintableSupply(),
            MAX_SUPPLY - INITIAL_SUPPLY - mintAmount
        );
    }

    // ================== Batch Mint 功能测试 ==================
    function test_BatchMint() public {
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 2000 * 10 ** 18;
        amounts[2] = 3000 * 10 ** 18;

        vm.prank(owner);
        token.batchMint(recipients, amounts);

        assertEq(token.balanceOf(user1), amounts[0]);
        assertEq(token.balanceOf(user2), amounts[1]);
        assertEq(token.balanceOf(user3), amounts[2]);
        assertEq(
            token.totalSupply(),
            INITIAL_SUPPLY + amounts[0] + amounts[1] + amounts[2]
        );
    }

    function test_BatchMintArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](3);

        recipients[0] = user1;
        recipients[1] = user2;
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 2000 * 10 ** 18;
        amounts[2] = 3000 * 10 ** 18;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: array length mismatch");
        token.batchMint(recipients, amounts);
    }

    function test_BatchMintTooManyRecipients() public {
        address[] memory recipients = new address[](201);
        uint256[] memory amounts = new uint256[](201);

        for (uint256 i = 0; i < 201; i++) {
            recipients[i] = address(uint160(i + 1));
            amounts[i] = 1 * 10 ** 18;
        }

        vm.prank(owner);
        vm.expectRevert("PlatformToken: too many recipients");
        token.batchMint(recipients, amounts);
    }

    function test_BatchMintZeroAddress() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = user1;
        recipients[1] = address(0);
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 2000 * 10 ** 18;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: mint to zero address");
        token.batchMint(recipients, amounts);
    }

    function test_BatchMintExceedsMaxSupply() public {
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = user1;
        recipients[1] = user2;
        amounts[0] = (MAX_SUPPLY - token.totalSupply()) / 2 + 1;
        amounts[1] = (MAX_SUPPLY - token.totalSupply()) / 2 + 1;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: exceeds max supply");
        token.batchMint(recipients, amounts);
    }

    // ================== Burn 功能测试 ==================
    function test_Burn() public {
        uint256 burnAmount = 1000 * 10 ** 18;

        // 先给 user1 一些代币
        vm.prank(owner);
        token.mint(user1, burnAmount * 2);

        vm.expectEmit(true, false, false, true);
        emit TokensBurned(user1, burnAmount);

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + burnAmount);
    }

    function test_BurnZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("PlatformToken: burn amount must be positive");
        token.burn(0);
    }

    function test_BurnInsufficientBalance() public {
        uint256 burnAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        vm.expectRevert();
        token.burn(burnAmount);
    }

    function test_BurnFrom() public {
        uint256 burnAmount = 1000 * 10 ** 18;

        // 给 user1 一些代币
        vm.prank(owner);
        token.mint(user1, burnAmount * 2);

        // user1 批准 user2 花费代币
        vm.prank(user1);
        token.approve(user2, burnAmount);

        vm.expectEmit(true, false, false, true);
        emit TokensBurned(user1, burnAmount);

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), burnAmount);
        assertEq(token.allowance(user1, user2), 0);
    }

    function test_BurnFromZeroAmount() public {
        vm.prank(user2);
        vm.expectRevert("PlatformToken: burn amount must be positive");
        token.burnFrom(user1, 0);
    }

    function test_BurnFromZeroAddress() public {
        vm.prank(user2);
        vm.expectRevert("PlatformToken: burn from zero address");
        token.burnFrom(address(0), 1000 * 10 ** 18);
    }

    function test_BurnFromInsufficientAllowance() public {
        uint256 burnAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, burnAmount);

        vm.prank(user2);
        vm.expectRevert();
        token.burnFrom(user1, burnAmount);
    }

    // ================== Pause 功能测试 ==================
    function test_Pause() public {
        vm.prank(owner);
        token.pause();

        assertTrue(token.paused());
    }

    function test_PauseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.pause();
    }

    function test_Unpause() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_UnpauseOnlyOwner() public {
        vm.prank(owner);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.unpause();
    }

    function test_TransferWhenPaused() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, transferAmount);

        vm.prank(owner);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, transferAmount);
    }

    function test_TransferWhenUnpaused() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, transferAmount);

        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        token.unpause();

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user2), transferAmount);
    }

    // ================== Emergency Withdraw 功能测试 ==================
    function test_EmergencyWithdraw() public {
        // 创建一个模拟的 ERC20 代币
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        uint256 withdrawAmount = 1000 * 10 ** 18;

        // 给合约发送一些模拟代币
        mockToken.mint(address(token), withdrawAmount);

        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdraw(address(mockToken), user1, withdrawAmount);

        vm.prank(owner);
        token.emergencyWithdraw(address(mockToken), user1, withdrawAmount);

        assertEq(mockToken.balanceOf(user1), withdrawAmount);
        assertEq(mockToken.balanceOf(address(token)), 0);
    }

    function test_EmergencyWithdrawOnlyOwner() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");

        vm.prank(user1);
        vm.expectRevert();
        token.emergencyWithdraw(address(mockToken), user1, 1000);
    }

    function test_EmergencyWithdrawSelf() public {
        vm.prank(owner);
        vm.expectRevert("PlatformToken: cannot withdraw self");
        token.emergencyWithdraw(address(token), user1, 1000);
    }

    function test_EmergencyWithdrawToZeroAddress() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");

        vm.prank(owner);
        vm.expectRevert("PlatformToken: withdraw to zero address");
        token.emergencyWithdraw(address(mockToken), address(0), 1000);
    }

    function test_EmergencyWithdrawInvalidTokenAddress() public {
        vm.prank(owner);
        vm.expectRevert("PlatformToken: invalid token address");
        token.emergencyWithdraw(address(0), user1, 1000);
    }

    function test_EmergencyWithdrawTokenToItself() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");

        vm.prank(owner);
        vm.expectRevert("PlatformToken: cannot send token to itself");
        token.emergencyWithdraw(address(mockToken), address(mockToken), 1000);
    }

    function test_EmergencyWithdrawInsufficientBalance() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK");
        uint256 withdrawAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        vm.expectRevert("PlatformToken: insufficient balance");
        token.emergencyWithdraw(address(mockToken), user1, withdrawAmount);
    }

    // ================== ERC20 基础功能测试 ==================
    function test_Transfer() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }

    function test_Approve() public {
        uint256 approveAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.approve(user1, approveAmount);

        assertEq(token.allowance(owner, user1), approveAmount);
    }

    function test_TransferFrom() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.approve(user1, transferAmount);

        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);

        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.allowance(owner, user1), 0);
    }

    // ================== Fuzz 测试 ==================
    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 1, token.remainMintableSupply());

        vm.prank(owner);
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, token.remainMintableSupply());
        burnAmount = bound(burnAmount, 1, mintAmount);

        vm.prank(owner);
        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
    }
}

// Mock ERC20 代币用于测试 emergencyWithdraw
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
