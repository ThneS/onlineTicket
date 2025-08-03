// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TicketManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TicketManagerTest is Test {
    TicketManager public ticketManager;
    address public owner;
    address public minter;
    address public verifier;
    address public user1;
    address public user2;
    address public user3;

    // 测试常量
    uint256 public constant EVENT_ID = 1;
    uint256 public constant SEAT_NUMBER = 101;
    uint256 public constant ORIGINAL_PRICE = 100e18;
    uint256 public constant CATEGORY = 1;
    uint256 public validFrom;
    uint256 public validUntil;
    string public constant SEAT_SECTION = "VIP";
    string public constant TOKEN_URI = "https://example.com/ticket/1";

    // 事件定义
    event TicketMinted(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed buyer,
        uint256 seatNumber,
        uint256 price
    );

    event TicketUsed(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed verifier
    );

    event TicketCancelled(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        string reason
    );

    event TicketStatusChanged(
        uint256 indexed tokenId,
        TicketManager.TicketStatus oldStatus,
        TicketManager.TicketStatus newStatus
    );

    event MinterAuthorized(address indexed minter, bool authorized);
    event VerifierAuthorized(address indexed verifier, bool authorized);

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        verifier = makeAddr("verifier");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // 设置时间
        validFrom = block.timestamp + 1 hours;
        validUntil = block.timestamp + 1 days;

        vm.prank(owner);
        ticketManager = new TicketManager(owner);
    }

    // ================== 部署测试 ==================
    function test_Deploy() public {
        assertEq(ticketManager.name(), "OnlineTicket NFT");
        assertEq(ticketManager.symbol(), "OTN");
        assertEq(ticketManager.owner(), owner);
        assertFalse(ticketManager.paused());
    }

    // ================== 权限管理测试 ==================
    function test_SetMinterAuthorization() public {
        vm.expectEmit(true, false, false, true);
        emit MinterAuthorized(minter, true);

        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        assertTrue(ticketManager.authorizedMinters(minter));
    }

    function test_SetMinterAuthorizationOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        ticketManager.setMinterAuthorization(minter, true);
    }

    function test_SetVerifierAuthorization() public {
        vm.expectEmit(true, false, false, true);
        emit VerifierAuthorized(verifier, true);

        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);

        assertTrue(ticketManager.authorizedVerifiers(verifier));
    }

    function test_SetVerifierAuthorizationOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        ticketManager.setVerifierAuthorization(verifier, true);
    }

    // ================== 门票铸造测试 ==================
    function test_MintTicket() public {
        // 授权铸造者
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        vm.expectEmit(true, true, true, true);
        emit TicketMinted(1, EVENT_ID, user1, SEAT_NUMBER, ORIGINAL_PRICE);

        vm.prank(minter);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        assertEq(tokenId, 1);
        assertEq(ticketManager.ownerOf(tokenId), user1);
        assertEq(ticketManager.balanceOf(user1), 1);
        assertEq(ticketManager.tokenURI(tokenId), TOKEN_URI);

        // 检查门票元数据
        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        assertEq(ticket.eventId, EVENT_ID);
        assertEq(ticket.seatNumber, SEAT_NUMBER);
        assertEq(ticket.originalPrice, ORIGINAL_PRICE);
        assertEq(ticket.category, CATEGORY);
        assertEq(ticket.validFrom, validFrom);
        assertEq(ticket.validUntil, validUntil);
        assertTrue(
            uint256(ticket.status) == uint256(TicketManager.TicketStatus.VALID)
        );
        assertEq(ticket.originalBuyer, user1);
        assertTrue(ticket.isTransferable);
        assertEq(ticket.seatSection, SEAT_SECTION);
    }

    function test_MintTicketUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert("TicketManager: unauthorized minter");
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketToZeroAddress() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        vm.prank(minter);
        vm.expectRevert("TicketManager: mint to zero address");
        ticketManager.mintTicket(
            address(0),
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketInvalidTimeRange() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        vm.prank(minter);
        vm.expectRevert("TicketManager: invalid time range");
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validUntil, // validFrom > validUntil
            validFrom,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketAlreadyExpired() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        // 跳转到未来，然后设置过期时间
        vm.warp(block.timestamp + 10 days);

        // 设置过期时间在当前时间之前
        uint256 expiredValidFrom = block.timestamp - 2 hours;
        uint256 expiredValidUntil = block.timestamp - 1 hours;

        vm.prank(minter);
        vm.expectRevert("TicketManager: already expired");
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            expiredValidFrom,
            expiredValidUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketSeatAlreadyTaken() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        // 铸造第一张门票
        vm.prank(minter);
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 尝试铸造相同座位的门票
        vm.prank(minter);
        vm.expectRevert("TicketManager: seat already taken");
        ticketManager.mintTicket(
            user2,
            EVENT_ID,
            SEAT_NUMBER, // 相同座位号
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketPurchaseLimitExceeded() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        // 设置购买限制为1
        vm.prank(owner);
        ticketManager.setEventPurchaseLimit(EVENT_ID, 1);

        // 铸造第一张门票
        vm.prank(minter);
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 尝试为同一用户铸造第二张门票
        vm.prank(minter);
        vm.expectRevert("TicketManager: purchase limit exceeded");
        ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER + 1,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );
    }

    function test_MintTicketOwnerCanMint() public {
        // 所有者不需要授权就可以铸造
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        assertEq(tokenId, 1);
        assertEq(ticketManager.ownerOf(tokenId), user1);
    }

    // ================== 批量铸造测试 ==================
    function test_BatchMintTickets() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        address[] memory recipients = new address[](3);
        uint256[] memory seatNumbers = new uint256[](3);
        string[] memory tokenURIs = new string[](3);

        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;
        seatNumbers[0] = 101;
        seatNumbers[1] = 102;
        seatNumbers[2] = 103;
        tokenURIs[0] = "https://example.com/1";
        tokenURIs[1] = "https://example.com/2";
        tokenURIs[2] = "https://example.com/3";

        vm.prank(minter);
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

        assertEq(tokenIds.length, 3);
        assertEq(ticketManager.ownerOf(tokenIds[0]), user1);
        assertEq(ticketManager.ownerOf(tokenIds[1]), user2);
        assertEq(ticketManager.ownerOf(tokenIds[2]), user3);
    }

    function test_BatchMintTicketsEmptyRecipients() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        address[] memory recipients = new address[](0);
        uint256[] memory seatNumbers = new uint256[](0);
        string[] memory tokenURIs = new string[](0);

        vm.prank(minter);
        vm.expectRevert("TicketManager: empty recipients");
        ticketManager.batchMintTickets(
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
    }

    function test_BatchMintTicketsArrayLengthMismatch() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        address[] memory recipients = new address[](2);
        uint256[] memory seatNumbers = new uint256[](3); // 长度不匹配
        string[] memory tokenURIs = new string[](2);

        recipients[0] = user1;
        recipients[1] = user2;

        vm.prank(minter);
        vm.expectRevert("TicketManager: array length mismatch");
        ticketManager.batchMintTickets(
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
    }

    function test_BatchMintTicketsTooLarge() public {
        vm.prank(owner);
        ticketManager.setMinterAuthorization(minter, true);

        address[] memory recipients = new address[](101); // 超过限制
        uint256[] memory seatNumbers = new uint256[](101);
        string[] memory tokenURIs = new string[](101);

        vm.prank(minter);
        vm.expectRevert("TicketManager: batch too large");
        ticketManager.batchMintTickets(
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
    }

    // ================== 门票验证与使用测试 ==================
    function test_UseTicket() public {
        // 先铸造一张门票
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 授权验证者
        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);

        // 跳转到有效时间
        vm.warp(validFrom + 1 hours);

        vm.expectEmit(true, true, true, false);
        emit TicketUsed(tokenId, EVENT_ID, verifier);

        vm.prank(verifier);
        ticketManager.useTicket(tokenId);

        // 检查状态已更新
        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        assertTrue(
            uint256(ticket.status) == uint256(TicketManager.TicketStatus.USED)
        );
    }

    function test_UseTicketUnauthorized() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.warp(validFrom + 1 hours);

        vm.prank(user1);
        vm.expectRevert("TicketManager: unauthorized verifier");
        ticketManager.useTicket(tokenId);
    }

    function test_UseTicketNotExists() public {
        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);

        vm.prank(verifier);
        vm.expectRevert("TicketManager: ticket does not exist");
        ticketManager.useTicket(999);
    }

    function test_UseTicketNotValid() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 取消门票
        vm.prank(owner);
        ticketManager.cancelTicket(tokenId, "Test cancellation");

        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);

        vm.warp(validFrom + 1 hours);

        vm.prank(verifier);
        vm.expectRevert("TicketManager: ticket not valid");
        ticketManager.useTicket(tokenId);
    }

    function test_UseTicketNotInValidTimeRange() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);

        // 在有效时间之前
        vm.warp(validFrom - 1 hours);

        vm.prank(verifier);
        vm.expectRevert("TicketManager: ticket not in valid time range");
        ticketManager.useTicket(tokenId);
    }

    function test_IsTicketValid() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 在有效时间之前
        vm.warp(validFrom - 1 hours);
        assertFalse(ticketManager.isTicketValid(tokenId));

        // 在有效时间内
        vm.warp(validFrom + 1 hours);
        assertTrue(ticketManager.isTicketValid(tokenId));

        // 在有效时间之后
        vm.warp(validUntil + 1 hours);
        assertFalse(ticketManager.isTicketValid(tokenId));
    }

    function test_VerifyTicketHash() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        bytes32 validHash = ticket.verificationHash;
        bytes32 invalidHash = keccak256("invalid");

        assertTrue(ticketManager.verifyTicketHash(tokenId, validHash));
        assertFalse(ticketManager.verifyTicketHash(tokenId, invalidHash));
    }

    // ================== 门票管理测试 ==================
    function test_CancelTicket() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.expectEmit(true, true, false, true);
        emit TicketCancelled(tokenId, EVENT_ID, "Test reason");

        vm.prank(owner);
        ticketManager.cancelTicket(tokenId, "Test reason");

        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        assertTrue(
            uint256(ticket.status) ==
                uint256(TicketManager.TicketStatus.CANCELLED)
        );
    }

    function test_CancelTicketOnlyOwner() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(user1);
        vm.expectRevert();
        ticketManager.cancelTicket(tokenId, "Test reason");
    }

    function test_SetTicketTransferable() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        ticketManager.setTicketTransferable(tokenId, false);

        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        assertFalse(ticket.isTransferable);
    }

    function test_SetEventPurchaseLimit() public {
        vm.prank(owner);
        ticketManager.setEventPurchaseLimit(EVENT_ID, 5);

        assertEq(ticketManager.eventPurchaseLimit(EVENT_ID), 5);
    }

    function test_ExpireTickets() public {
        // 铸造两张门票
        vm.prank(owner);
        uint256 tokenId1 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            101,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        uint256 tokenId2 = ticketManager.mintTicket(
            user2,
            EVENT_ID,
            102,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        vm.prank(owner);
        ticketManager.expireTickets(tokenIds);

        TicketManager.TicketMetadata memory ticket1 = ticketManager
            .getTicketInfo(tokenId1);
        TicketManager.TicketMetadata memory ticket2 = ticketManager
            .getTicketInfo(tokenId2);

        assertTrue(
            uint256(ticket1.status) ==
                uint256(TicketManager.TicketStatus.EXPIRED)
        );
        assertTrue(
            uint256(ticket2.status) ==
                uint256(TicketManager.TicketStatus.EXPIRED)
        );
    }

    // ================== 转移控制测试 ==================
    function test_TransferTicket() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true, // 可转让
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(user1);
        ticketManager.transferFrom(user1, user2, tokenId);

        assertEq(ticketManager.ownerOf(tokenId), user2);
    }

    function test_TransferNonTransferableTicket() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            false, // 不可转让
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(user1);
        vm.expectRevert("TicketManager: ticket not transferable");
        ticketManager.transferFrom(user1, user2, tokenId);
    }

    function test_TransferUsedTicket() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 使用门票
        vm.prank(owner);
        ticketManager.setVerifierAuthorization(verifier, true);
        vm.warp(validFrom + 1 hours);
        vm.prank(verifier);
        ticketManager.useTicket(tokenId);

        vm.prank(user1);
        vm.expectRevert("TicketManager: invalid ticket status");
        ticketManager.transferFrom(user1, user2, tokenId);
    }

    function test_TransferWhenPaused() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        ticketManager.pause();

        vm.prank(user1);
        vm.expectRevert();
        ticketManager.transferFrom(user1, user2, tokenId);
    }

    // ================== 查询功能测试 ==================
    function test_GetEventTickets() public {
        vm.prank(owner);
        uint256 tokenId1 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            101,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        uint256 tokenId2 = ticketManager.mintTicket(
            user2,
            EVENT_ID,
            102,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        uint256[] memory eventTickets = ticketManager.getEventTickets(EVENT_ID);
        assertEq(eventTickets.length, 2);
        assertEq(eventTickets[0], tokenId1);
        assertEq(eventTickets[1], tokenId2);
    }

    function test_GetUserEventTickets() public {
        vm.prank(owner);
        uint256 tokenId1 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            101,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        ticketManager.mintTicket(
            user2,
            EVENT_ID,
            102,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        uint256 tokenId3 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            103,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        uint256[] memory userTickets = ticketManager.getUserEventTickets(
            user1,
            EVENT_ID
        );
        assertEq(userTickets.length, 2);
        assertEq(userTickets[0], tokenId1);
        assertEq(userTickets[1], tokenId3);
    }

    function test_GetUserTickets() public {
        vm.prank(owner);
        uint256 tokenId1 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            101,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        vm.prank(owner);
        uint256 tokenId2 = ticketManager.mintTicket(
            user1,
            EVENT_ID + 1,
            102,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        uint256[] memory userTickets = ticketManager.getUserTickets(user1);
        assertEq(userTickets.length, 2);
        assertEq(userTickets[0], tokenId1);
        assertEq(userTickets[1], tokenId2);
    }

    // ================== 管理功能测试 ==================
    function test_Pause() public {
        vm.prank(owner);
        ticketManager.pause();

        assertTrue(ticketManager.paused());
    }

    function test_PauseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        ticketManager.pause();
    }

    function test_Unpause() public {
        vm.prank(owner);
        ticketManager.pause();

        vm.prank(owner);
        ticketManager.unpause();

        assertFalse(ticketManager.paused());
    }

    function test_EmergencyWithdrawETH() public {
        // 向合约发送一些ETH
        vm.deal(address(ticketManager), 1 ether);

        uint256 beforeBalance = owner.balance;

        vm.prank(owner);
        ticketManager.emergencyWithdraw(address(0), owner, 0.5 ether);

        assertEq(owner.balance, beforeBalance + 0.5 ether);
    }

    function test_EmergencyWithdrawToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("TicketManager: withdraw to zero address");
        ticketManager.emergencyWithdraw(address(0), address(0), 1 ether);
    }

    // ================== ERC721 基础功能测试 ==================
    function test_SupportsInterface() public {
        // ERC721
        assertTrue(ticketManager.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(ticketManager.supportsInterface(0x5b5e139f));
        // ERC721Enumerable
        assertTrue(ticketManager.supportsInterface(0x780e9d63));
    }

    function test_TokenURI() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        assertEq(ticketManager.tokenURI(tokenId), TOKEN_URI);
    }

    // ================== 边界情况测试 ==================
    function test_MintTicketWithoutSeat() public {
        vm.prank(owner);
        uint256 tokenId = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            0, // 无座位
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        TicketManager.TicketMetadata memory ticket = ticketManager
            .getTicketInfo(tokenId);
        assertEq(ticket.seatNumber, 0);
    }

    function test_MultipleEventsDoNotConflict() public {
        vm.prank(owner);
        uint256 tokenId1 = ticketManager.mintTicket(
            user1,
            EVENT_ID,
            SEAT_NUMBER,
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        // 不同活动可以有相同座位号
        vm.prank(owner);
        uint256 tokenId2 = ticketManager.mintTicket(
            user2,
            EVENT_ID + 1,
            SEAT_NUMBER, // 相同座位号但不同活动
            ORIGINAL_PRICE,
            CATEGORY,
            validFrom,
            validUntil,
            true,
            SEAT_SECTION,
            TOKEN_URI
        );

        assertEq(ticketManager.ownerOf(tokenId1), user1);
        assertEq(ticketManager.ownerOf(tokenId2), user2);
    }
}
