// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TicketManager.sol";

contract TicketManagerTest is Test {
    TicketManager public ticketManager;

    address public owner = address(0x99);
    address public organizer = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public minter = address(0x5);
    address public verifier = address(0x6);

    function setUp() public {
        vm.prank(owner);
        ticketManager = new TicketManager(owner);

        // 给测试地址分配ETH
        vm.deal(organizer, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(minter, 10 ether);

        // 设置授权
        vm.startPrank(owner);
        ticketManager.setMinterAuthorization(minter, true);
        ticketManager.setVerifierAuthorization(verifier, true);
        vm.stopPrank();
    }

    function testInitialState() public {
        console.log("=== Testing TicketManager Initial State ===");

        assertEq(ticketManager.name(), "OnlineTicket NFT");
        assertEq(ticketManager.symbol(), "OTN");
        assertEq(ticketManager.owner(), owner);
        assertFalse(ticketManager.paused());

        console.log("NFT Name:", ticketManager.name());
        console.log("NFT Symbol:", ticketManager.symbol());
        console.log("Owner:", ticketManager.owner());
        console.log(unicode"✅ Initial state test passed");
    }

    function testMintTicket() public {
        console.log("\n=== Testing Mint Ticket ===");

        uint256 eventId = 1;
        uint256 seatNumber = 101;
        uint256 originalPrice = 0.1 ether;
        uint256 category = 1; // VIP
        uint256 validFrom = block.timestamp;
        uint256 validUntil = block.timestamp + 30 days;
        bool isTransferable = true;
        string memory seatSection = "VIP Section";

        console.log("Event ID:", eventId);
        console.log("Seat Number:", seatNumber);
        console.log("Original Price:", originalPrice / 10 ** 18);
        console.log("Category:", category);
        console.log("Seat Section:", seatSection);

        vm.prank(minter);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            eventId,
            seatNumber,
            originalPrice,
            category,
            validFrom,
            validUntil,
            isTransferable,
            seatSection,
            "ipfs://QmHash123" // uri parameter
        );

        assertGt(tokenId, 0);
        assertEq(ticketManager.ownerOf(tokenId), user1);
        assertEq(ticketManager.balanceOf(user1), 1);

        // 检查票据信息
        TicketManager.TicketMetadata memory ticketInfo = ticketManager
            .getTicketInfo(tokenId);

        assertEq(ticketInfo.eventId, eventId);
        assertEq(ticketInfo.seatNumber, seatNumber);
        assertEq(ticketInfo.originalPrice, originalPrice);
        assertEq(ticketInfo.category, category);
        assertEq(ticketInfo.validFrom, validFrom);
        assertEq(ticketInfo.validUntil, validUntil);
        assertEq(ticketInfo.originalBuyer, user1);
        assertEq(ticketInfo.purchaseTime, block.timestamp);
        assertTrue(ticketInfo.isTransferable);
        assertEq(ticketInfo.seatSection, seatSection);

        console.log("Token ID:", tokenId);
        console.log("Original Buyer:", ticketInfo.originalBuyer);
        console.log("Purchase Time:", ticketInfo.purchaseTime);
        console.log("Is Transferable:", ticketInfo.isTransferable);
        console.log(unicode"✅ Mint ticket test passed");
    }

    function testBatchMintTickets() public {
        console.log("\n=== Testing Batch Mint Tickets ===");

        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = organizer;

        uint256[] memory eventIds = new uint256[](3);
        eventIds[0] = 1;
        eventIds[1] = 1;
        eventIds[2] = 2;

        uint256[] memory seatNumbers = new uint256[](3);
        seatNumbers[0] = 101;
        seatNumbers[1] = 102;
        seatNumbers[2] = 201;

        uint256[] memory originalPrices = new uint256[](3);
        originalPrices[0] = 0.1 ether;
        originalPrices[1] = 0.1 ether;
        originalPrices[2] = 0.2 ether;

        uint256[] memory categories = new uint256[](3);
        categories[0] = 1;
        categories[1] = 1;
        categories[2] = 2;

        uint256[] memory validFroms = new uint256[](3);
        validFroms[0] = block.timestamp;
        validFroms[1] = block.timestamp;
        validFroms[2] = block.timestamp;

        uint256[] memory validUntils = new uint256[](3);
        validUntils[0] = block.timestamp + 30 days;
        validUntils[1] = block.timestamp + 30 days;
        validUntils[2] = block.timestamp + 60 days;

        bool[] memory isTransferables = new bool[](3);
        isTransferables[0] = true;
        isTransferables[1] = true;
        isTransferables[2] = false;

        string[] memory seatSections = new string[](3);
        seatSections[0] = "VIP Section A";
        seatSections[1] = "VIP Section A";
        seatSections[2] = "Premium Section";

        string[] memory tokenURIs = new string[](3);
        tokenURIs[0] = "ipfs://QmHash1";
        tokenURIs[1] = "ipfs://QmHash2";
        tokenURIs[2] = "ipfs://QmHash3";

        console.log("Batch Size:", recipients.length);

        // 为event 1批量铸造票据
        vm.prank(minter);
        uint256[] memory tokenIds = ticketManager.batchMintTickets(
            recipients,
            1, // eventId - 统一为event 1
            seatNumbers,
            0.1 ether, // originalPrice - 统一价格
            1, // category - 统一类别
            block.timestamp, // validFrom
            block.timestamp + 30 days, // validUntil
            true, // isTransferable
            "VIP Section A", // seatSection
            tokenURIs
        );

        assertEq(tokenIds.length, 3);
        assertEq(ticketManager.balanceOf(user1), 1);
        assertEq(ticketManager.balanceOf(user2), 1);
        assertEq(ticketManager.balanceOf(organizer), 1);

        for (uint i = 0; i < tokenIds.length; i++) {
            assertEq(ticketManager.ownerOf(tokenIds[i]), recipients[i]);
            console.log("Token ID:", tokenIds[i]);
            console.log("Owner:", recipients[i]);
        }

        console.log(unicode"✅ Batch mint tickets test passed");
    }

    function testUseTicket() public {
        testMintTicket();

        console.log("\n=== Testing Use Ticket ===");

        uint256 tokenId = 1;

        console.log("Token ID:", tokenId);

        // 检查票据使用前状态
        assertTrue(ticketManager.isTicketValid(tokenId));
        console.log("Ticket valid before use:", true);

        // 验证者使用票据 - useTicket只需要tokenId参数
        vm.prank(verifier);
        ticketManager.useTicket(tokenId);

        // 检查票据使用后状态
        assertFalse(ticketManager.isTicketValid(tokenId));
        console.log("Ticket valid after use:", false);

        console.log(unicode"✅ Use ticket test passed");
    }

    function testTicketTransfer() public {
        testMintTicket();

        console.log("\n=== Testing Ticket Transfer ===");

        uint256 tokenId = 1;

        console.log("Owner before transfer:", ticketManager.ownerOf(tokenId));
        console.log("User1 balance before:", ticketManager.balanceOf(user1));
        console.log("User2 balance before:", ticketManager.balanceOf(user2));

        vm.prank(user1);
        ticketManager.transferFrom(user1, user2, tokenId);

        assertEq(ticketManager.ownerOf(tokenId), user2);
        assertEq(ticketManager.balanceOf(user1), 0);
        assertEq(ticketManager.balanceOf(user2), 1);

        console.log("Owner after transfer:", ticketManager.ownerOf(tokenId));
        console.log("User1 balance after:", ticketManager.balanceOf(user1));
        console.log("User2 balance after:", ticketManager.balanceOf(user2));
        console.log(unicode"✅ Ticket transfer test passed");
    }

    function testNonTransferableTicket() public {
        console.log("\n=== Testing Non-Transferable Ticket ===");

        // 创建不可转让的票据
        vm.prank(minter);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            1,
            101,
            0.1 ether,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            false, // 不可转让
            "VIP Section",
            "ipfs://QmHash456" // uri parameter
        );

        console.log("Created non-transferable ticket:", tokenId);

        // 尝试转让应该失败
        vm.prank(user1);
        vm.expectRevert("TicketManager: ticket not transferable");
        ticketManager.transferFrom(user1, user2, tokenId);

        console.log(unicode"✅ Non-transferable protection working");
    }

    function testCancelTicket() public {
        testMintTicket();

        console.log("\n=== Testing Cancel Ticket ===");

        uint256 tokenId = 1;

        console.log("Token ID:", tokenId);
        console.log(
            "Valid before cancel:",
            ticketManager.isTicketValid(tokenId)
        );

        vm.prank(owner);
        ticketManager.cancelTicket(tokenId, "Test cancellation reason");

        assertFalse(ticketManager.isTicketValid(tokenId));
        console.log(
            "Valid after cancel:",
            ticketManager.isTicketValid(tokenId)
        );
        console.log(unicode"✅ Cancel ticket test passed");
    }

    function testSetTicketTransferable() public {
        testMintTicket();

        console.log("\n=== Testing Set Ticket Transferable ===");

        uint256 tokenId = 1;

        // 检查初始状态
        TicketManager.TicketMetadata memory ticketInfo = ticketManager
            .getTicketInfo(tokenId);
        assertTrue(ticketInfo.isTransferable);
        console.log("Initially transferable:", ticketInfo.isTransferable);

        // 设置为不可转让
        vm.prank(owner);
        ticketManager.setTicketTransferable(tokenId, false);

        ticketInfo = ticketManager.getTicketInfo(tokenId);
        assertFalse(ticketInfo.isTransferable);
        console.log("After setting to false:", ticketInfo.isTransferable);

        console.log(unicode"✅ Set ticket transferable test passed");
    }

    function testGetEventTickets() public {
        testBatchMintTickets();

        console.log("\n=== Testing Get Event Tickets ===");

        uint256 eventId = 1;
        uint256[] memory eventTickets = ticketManager.getEventTickets(eventId);

        assertEq(eventTickets.length, 2); // 前两张票属于 event 1
        console.log("Event", eventId, "tickets count:", eventTickets.length);

        for (uint i = 0; i < eventTickets.length; i++) {
            console.log("Event ticket", i + 1, "ID:", eventTickets[i]);
        }

        console.log(unicode"✅ Get event tickets test passed");
    }

    function testGetUserTickets() public {
        testBatchMintTickets();

        console.log("\n=== Testing Get User Tickets ===");

        uint256[] memory user1Tickets = ticketManager.getUserTickets(user1);
        uint256[] memory user2Tickets = ticketManager.getUserTickets(user2);

        assertEq(user1Tickets.length, 1);
        assertEq(user2Tickets.length, 1);

        console.log("User1 tickets count:", user1Tickets.length);
        console.log("User2 tickets count:", user2Tickets.length);

        for (uint i = 0; i < user1Tickets.length; i++) {
            console.log("User1 ticket", i + 1, "ID:", user1Tickets[i]);
        }

        console.log(unicode"✅ Get user tickets test passed");
    }

    function testPauseContract() public {
        console.log("\n=== Testing Pause Contract ===");

        vm.prank(owner);
        ticketManager.pause();

        assertTrue(ticketManager.paused());
        console.log("Contract paused");

        // 暂停时不能铸造
        vm.prank(minter);
        vm.expectRevert();
        ticketManager.mintTicket(
            user1,
            1,
            101,
            0.1 ether,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP Section",
            "ipfs://QmHash789" // uri parameter
        );

        console.log("Minting blocked when paused");

        // 取消暂停
        vm.prank(owner);
        ticketManager.unpause();

        assertFalse(ticketManager.paused());
        console.log("Contract unpaused");
        console.log(unicode"✅ Pause/unpause test passed");
    }

    function testUnauthorizedMinting() public {
        console.log("\n=== Testing Unauthorized Minting ===");

        // 未授权用户尝试铸造
        vm.prank(user1);
        vm.expectRevert("TicketManager: unauthorized minter");
        ticketManager.mintTicket(
            user1,
            1,
            101,
            0.1 ether,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP Section",
            "ipfs://QmHashABC" // uri parameter
        );

        console.log(unicode"✅ Unauthorized minting protection working");
    }

    function testEmergencyWithdraw() public {
        console.log("\n=== Testing Emergency Withdraw ===");

        // 发送一些ETH到合约
        vm.deal(address(ticketManager), 1 ether);

        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalance = address(ticketManager).balance;

        console.log("Contract Balance:", contractBalance / 10 ** 18);
        console.log("Owner Balance Before:", ownerBalanceBefore / 10 ** 18);

        vm.prank(owner);
        ticketManager.emergencyWithdraw(address(0), owner, contractBalance);

        assertEq(address(ticketManager).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);

        console.log("Owner Balance After:", owner.balance / 10 ** 18);
        console.log(unicode"✅ Emergency withdraw test passed");
    }
}
