// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/PlatformToken.sol";

/**
 * @title PlatformToken 部署和测试脚本
 * @dev 用于演示 PlatformToken 合约的主要功能
 */
contract PlatformTokenDemo is Script {
    PlatformToken public token;
    address public owner;
    address public user1;
    address public user2;

    function run() public {
        // 设置测试账户
        owner = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        console.log("=== PlatformToken Contract Demo ===");
        console.log("Owner:", owner);
        console.log("User1:", user1);
        console.log("User2:", user2);

        // 部署合约
        vm.startPrank(owner);
        token = new PlatformToken(owner);
        console.log("\n[SUCCESS] Contract deployed successfully");
        console.log("Contract address:", address(token));

        // 显示基本信息
        showBasicInfo();

        // 演示铸造功能
        demonstrateMint();

        // 演示批量铸造
        demonstrateBatchMint();

        // 演示转账功能
        demonstrateTransfer();

        // 演示销毁功能
        demonstrateBurn();

        // 演示暂停功能
        demonstratePause();

        vm.stopPrank();

        console.log("\n[COMPLETE] All functions demonstrated successfully!");
    }

    function showBasicInfo() internal view {
        console.log("\n=== Contract Basic Info ===");
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Max supply:", token.MAX_SUPPLY() / 1e18, "tokens");
        console.log(
            "Current total supply:",
            token.totalSupply() / 1e18,
            "tokens"
        );
        console.log("Owner balance:", token.balanceOf(owner) / 1e18, "tokens");
        console.log(
            "Remaining mintable:",
            token.remainMintableSupply() / 1e18,
            "tokens"
        );
    }

    function demonstrateMint() internal {
        console.log("\n=== Mint Function Demo ===");
        uint256 mintAmount = 10000 * 1e18;

        uint256 beforeBalance = token.balanceOf(user1);
        uint256 beforeSupply = token.totalSupply();

        token.mint(user1, mintAmount);

        console.log("Minted to user1:", mintAmount / 1e18, "tokens");
        console.log(
            "user1 balance change:",
            beforeBalance / 1e18,
            "->",
            token.balanceOf(user1) / 1e18
        );
        console.log(
            "Total supply change:",
            beforeSupply / 1e18,
            "->",
            token.totalSupply() / 1e18
        );
    }

    function demonstrateBatchMint() internal {
        console.log("\n=== Batch Mint Function Demo ===");

        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        recipients[0] = user1;
        recipients[1] = user2;
        amounts[0] = 5000 * 1e18;
        amounts[1] = 3000 * 1e18;

        uint256 user1Before = token.balanceOf(user1);
        uint256 user2Before = token.balanceOf(user2);

        token.batchMint(recipients, amounts);

        console.log("Batch mint completed:");
        console.log(
            "user1 balance change:",
            user1Before / 1e18,
            "->",
            token.balanceOf(user1) / 1e18
        );
        console.log(
            "user2 balance change:",
            user2Before / 1e18,
            "->",
            token.balanceOf(user2) / 1e18
        );
    }

    function demonstrateTransfer() internal {
        console.log("\n=== Transfer Function Demo ===");

        uint256 transferAmount = 1000 * 1e18;
        uint256 ownerBefore = token.balanceOf(owner);
        uint256 user1Before = token.balanceOf(user1);

        token.transfer(user1, transferAmount);

        console.log(
            "Transfer",
            transferAmount / 1e18,
            "tokens from owner to user1"
        );
        console.log(
            "owner balance change:",
            ownerBefore / 1e18,
            "->",
            token.balanceOf(owner) / 1e18
        );
        console.log(
            "user1 balance change:",
            user1Before / 1e18,
            "->",
            token.balanceOf(user1) / 1e18
        );
    }

    function demonstrateBurn() internal {
        console.log("\n=== Burn Function Demo ===");

        uint256 burnAmount = 2000 * 1e18;
        uint256 beforeBalance = token.balanceOf(owner);
        uint256 beforeSupply = token.totalSupply();

        token.burn(burnAmount);

        console.log("Burned", burnAmount / 1e18, "tokens");
        console.log(
            "owner balance change:",
            beforeBalance / 1e18,
            "->",
            token.balanceOf(owner) / 1e18
        );
        console.log(
            "Total supply change:",
            beforeSupply / 1e18,
            "->",
            token.totalSupply() / 1e18
        );
    }

    function demonstratePause() internal {
        console.log("\n=== Pause Function Demo ===");

        console.log(
            "Before pause status:",
            token.paused() ? "Paused" : "Not paused"
        );

        token.pause();
        console.log("Execute pause operation");
        console.log(
            "After pause status:",
            token.paused() ? "Paused" : "Not paused"
        );

        token.unpause();
        console.log("Execute unpause operation");
        console.log("Final status:", token.paused() ? "Paused" : "Not paused");
    }
}
