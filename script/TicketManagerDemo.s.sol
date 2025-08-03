// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/TicketManager.sol";

/**
 * @title TicketManager 部署和测试脚本
 * @dev 用于演示 TicketManager 合约的主要功能
 */
contract TicketManagerDemo is Script {
    TicketManager public ticketManager;
    address public owner;
    address public minter;
    address public verifier;
    address public user1;
    address public user2;

    // 演示数据
    uint256 public constant EVENT_ID = 1;
    uint256 public constant ORIGINAL_PRICE = 100e18;
    uint256 public constant CATEGORY = 1;
    uint256 public validFrom;
    uint256 public validUntil;
    string public constant SEAT_SECTION = "VIP";

    function run() public {
        // 设置测试账户
        owner = vm.addr(1);
        minter = vm.addr(2);
        verifier = vm.addr(3);
        user1 = vm.addr(4);
        user2 = vm.addr(5);

        // 设置时间
        validFrom = block.timestamp + 1 hours;
        validUntil = block.timestamp + 1 days;

        console.log("=== TicketManager Contract Demo ===");
        console.log("Owner:", owner);
        console.log("Minter:", minter);
        console.log("Verifier:", verifier);
        console.log("User1:", user1);
        console.log("User2:", user2);

        // 部署合约
        vm.startPrank(owner);
        ticketManager = new TicketManager(owner);
        console.log("\n[SUCCESS] Contract deployed successfully");
        console.log("Contract address:", address(ticketManager));

        // 显示基本信息
        showBasicInfo();

        // 演示权限管理
        demonstrateAuthorization();

        // 演示门票铸造
        demonstrateMinting();

        // 演示批量铸造
        demonstrateBatchMinting();

        // 演示门票验证和使用
        demonstrateTicketUsage();

        // 演示门票管理
        demonstrateTicketManagement();

        // 演示查询功能
        demonstrateQueries();

        vm.stopPrank();

        console.log("\n[COMPLETE] All functions demonstrated successfully!");
    }

    function showBasicInfo() internal view {
        console.log("\n=== Contract Basic Info ===");
        console.log("Token name:", ticketManager.name());
        console.log("Token symbol:", ticketManager.symbol());
        console.log("Owner:", ticketManager.owner());
        console.log("Paused:", ticketManager.paused() ? "Yes" : "No");
        console.log("Total Supply:", ticketManager.totalSupply());
    }

    function demonstrateAuthorization() internal {
        console.log("\n=== Authorization Demo ===");

        // 授权铸造者
        ticketManager.setMinterAuthorization(minter, true);
        console.log(
            "Minter authorized:",
            ticketManager.authorizedMinters(minter) ? "Yes" : "No"
        );

        // 授权验证者
        ticketManager.setVerifierAuthorization(verifier, true);
        console.log(
            "Verifier authorized:",
            ticketManager.authorizedVerifiers(verifier) ? "Yes" : "No"
        );
    }

    function demonstrateMinting() internal {
        console.log("\n=== Ticket Minting Demo ===");

        vm.stopPrank();
        vm.startPrank(minter);

        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            101,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            "https://example.com/ticket/1"
        );

        console.log("Minted ticket ID:", tokenId);
        console.log("Ticket owner:", ticketManager.ownerOf(tokenId));
        console.log("User1 balance:", ticketManager.balanceOf(user1));

        vm.stopPrank();
        vm.startPrank(owner);
    }

    function demonstrateBatchMinting() internal {
        console.log("\n=== Batch Minting Demo ===");

        vm.stopPrank();
        vm.startPrank(minter);

        address[] memory recipients = new address[](2);
        uint256[] memory seatNumbers = new uint256[](2);
        string[] memory tokenURIs = new string[](2);

        recipients[0] = user1;
        recipients[1] = user2;
        seatNumbers[0] = 102;
        seatNumbers[1] = 103;
        tokenURIs[0] = "https://example.com/ticket/2";
        tokenURIs[1] = "https://example.com/ticket/3";

        uint256[] memory tokenIds = ticketManager.batchMintTickets(
            recipients,
            EVENT_ID,
            seatNumbers,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            tokenURIs
        );

        console.log("Batch minted", tokenIds.length, "tickets");
        console.log("First token ID:", tokenIds[0]);
        console.log("Second token ID:", tokenIds[1]);
        console.log("User1 total balance:", ticketManager.balanceOf(user1));
        console.log("User2 total balance:", ticketManager.balanceOf(user2));

        vm.stopPrank();
        vm.startPrank(owner);
    }

    function demonstrateTicketUsage() internal {
        console.log("\n=== Ticket Usage Demo ===");

        uint256 tokenId = 1; // 第一张铸造的门票

        // 检查门票有效性
        console.log(
            "Before time warp - ticket valid:",
            ticketManager.isTicketValid(tokenId) ? "Yes" : "No"
        );

        // 跳转到有效时间
        vm.warp(validFrom + 1 hours);
        console.log(
            "After time warp - ticket valid:",
            ticketManager.isTicketValid(tokenId) ? "Yes" : "No"
        );

        // 使用门票
        vm.stopPrank();
        vm.startPrank(verifier);

        ticketManager.useTicket(tokenId);
        console.log("Ticket used successfully");

        vm.stopPrank();
        vm.startPrank(owner);

        // 再次检查有效性
        console.log(
            "After usage - ticket valid:",
            ticketManager.isTicketValid(tokenId) ? "Yes" : "No"
        );

        // 检查门票状态
        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        console.log("Ticket status:", uint256(ticket.status));
    }

    function demonstrateTicketManagement() internal {
        console.log("\n=== Ticket Management Demo ===");

        uint256 tokenId = 2; // 第二张门票

        // 设置购买限制
        ticketManager.setEventPurchaseLimit(EVENT_ID, 5);
        console.log(
            "Purchase limit set to:",
            ticketManager.eventPurchaseLimit(EVENT_ID)
        );

        // 取消门票
        ticketManager.cancelTicket(tokenId, "Demo cancellation");
        console.log("Ticket", tokenId, "cancelled");

        // 检查状态
        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        console.log("Cancelled ticket status:", uint256(ticket.status));

        // 设置转让权限
        uint256 tokenId3 = 3;
        ticketManager.setTicketTransferable(tokenId3, false);
        TicketManager.TicketMetadata memory ticket3 = ticketManager
            .getTicketInfo(tokenId3);
        console.log(
            "Ticket",
            tokenId3,
            "transferable:",
            ticket3.isTransferable ? "Yes" : "No"
        );
    }

    function demonstrateQueries() internal view {
        console.log("\n=== Query Functions Demo ===");

        // 获取活动门票
        uint256[] memory eventTickets = ticketManager.getEventTickets(EVENT_ID);
        console.log(
            "Total tickets for event",
            EVENT_ID,
            ":",
            eventTickets.length
        );

        // 获取用户门票
        uint256[] memory user1Tickets = ticketManager.getUserTickets(user1);
        console.log("User1 total tickets:", user1Tickets.length);

        uint256[] memory user1EventTickets = ticketManager.getUserEventTickets(
            user1,
            EVENT_ID
        );
        console.log(
            "User1 tickets for event",
            EVENT_ID,
            ":",
            user1EventTickets.length
        );

        // 显示门票详情
        if (eventTickets.length > 0) {
            TicketManager.TicketMetadata memory ticket = ticketManager
                .getTicketInfo(eventTickets[0]);
            console.log("\nFirst ticket details:");
            console.log("Event ID:", ticket.eventId);
            console.log("Seat Number:", ticket.seatNumber);
            console.log(
                "Original Price:",
                ticket.originalPrice / 1e18,
                "tokens"
            );
            console.log("Category:", ticket.category);
            console.log("Original Buyer:", ticket.originalBuyer);
            console.log("Transferable:", ticket.isTransferable ? "Yes" : "No");
            console.log("Seat Section:", ticket.seatSection);
        }
    }
}
