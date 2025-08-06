// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/EventManager.sol";
import "../src/TicketManager.sol";
import "../src/PlatformToken.sol";

/**
 * @title EventManagerTest
 * @dev EventManager合约的基础测试套件
 */
contract EventManagerTest is Test {
    // 合约实例
    EventManager public eventManager;
    TicketManager public ticketManager;
    PlatformToken public platformToken;

    // 测试账户
    address public owner;
    address public organizer;
    address public buyer;
    address public minter;

    // 测试常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000e18;
    uint256 public constant TICKET_PRICE = 1000e18;
    uint256 public constant ETH_TICKET_PRICE = 1 ether;
    uint256 public constant TICKET_SUPPLY = 100;

    // 测试数据
    uint256 public eventId;
    uint256 public ticketTypeId;
    uint256 public startTime;
    uint256 public endTime;

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        organizer = makeAddr("organizer");
        buyer = makeAddr("buyer");
        minter = makeAddr("minter");

        // 部署合约
        platformToken = new PlatformToken(owner);
        ticketManager = new TicketManager(owner);
        eventManager = new EventManager(
            owner,
            address(ticketManager),
            address(platformToken)
        );

        // 设置时间
        startTime = block.timestamp + 7 days;
        endTime = startTime + 3 hours;

        // 设置权限
        ticketManager.setMinterAuthorization(address(eventManager), true);
        eventManager.authorizeOrganizer(organizer, true);

        // 为测试用户分发代币和ETH
        platformToken.mint(buyer, INITIAL_SUPPLY);
        vm.deal(buyer, 10 ether);

        // 买家授权EventManager操作代币
        vm.prank(buyer);
        platformToken.approve(address(eventManager), type(uint256).max);
    }

    // 接收ETH
    receive() external payable {}

    // ============ 基础测试 ============

    function test_Deployment() public {
        assertEq(address(eventManager.ticketManager()), address(ticketManager));
        assertEq(address(eventManager.platformToken()), address(platformToken));
        assertEq(eventManager.owner(), owner);
        assertEq(eventManager.defaultOrganizerFeeRate(), 500); // 5%
        assertEq(eventManager.platformFeeRate(), 250); // 2.5%
    }

    function test_AuthorizeOrganizer() public {
        address newOrganizer = makeAddr("newOrganizer");

        eventManager.authorizeOrganizer(newOrganizer, true);
        assertTrue(eventManager.authorizedOrganizers(newOrganizer));

        eventManager.authorizeOrganizer(newOrganizer, false);
        assertFalse(eventManager.authorizedOrganizers(newOrganizer));
    }

    function test_CreateEvent() public {
        vm.prank(organizer);
        eventId = eventManager.createEvent(
            "Test Concert",
            "A great concert",
            "https://example.com/image.jpg",
            "Test Venue",
            startTime,
            endTime,
            false // 不需要审批
        );

        assertEq(eventId, 1);

        // 验证活动信息
        (
            string memory name,
            string memory description,
            string memory imageURI,
            string memory venue,
            address eventOrganizer,
            uint256 eventStartTime,
            uint256 eventEndTime,
            EventManager.EventStatus status,
            ,
            ,
            ,
            ,
            ,

        ) = eventManager.getEventInfo(eventId);

        assertEq(name, "Test Concert");
        assertEq(description, "A great concert");
        assertEq(imageURI, "https://example.com/image.jpg");
        assertEq(venue, "Test Venue");
        assertEq(eventOrganizer, organizer);
        assertEq(eventStartTime, startTime);
        assertEq(eventEndTime, endTime);
        assertTrue(status == EventManager.EventStatus.PUBLISHED);
    }

    function test_AddTicketType() public {
        // 先创建活动
        vm.prank(organizer);
        eventId = eventManager.createEvent(
            "Test Concert",
            "A great concert",
            "",
            "Test Venue",
            startTime,
            endTime,
            false
        );

        // 添加票种
        vm.prank(organizer);
        ticketTypeId = eventManager.addTicketType(
            eventId,
            "VIP Ticket",
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            TICKET_SUPPLY,
            block.timestamp, // 预售开始时间
            block.timestamp + 1 hours, // 正式销售开始时间
            startTime - 1 hours, // 销售结束时间
            true, // 可转让
            false // 非仅预售
        );

        assertEq(ticketTypeId, 0);

        // 验证票种信息
        (
            string memory name,
            uint256 price,
            uint256 ethPrice,
            uint256 totalSupply,
            uint256 sold,
            ,
            ,
            ,
            ,

        ) = eventManager.getTicketTypeInfo(eventId, ticketTypeId);

        assertEq(name, "VIP Ticket");
        assertEq(price, TICKET_PRICE);
        assertEq(ethPrice, ETH_TICKET_PRICE);
        assertEq(totalSupply, TICKET_SUPPLY);
        assertEq(sold, 0);
    }

    function test_PurchaseTicketsWithToken() public {
        // 创建活动和票种
        _createEventWithTicketType();

        // 更新活动状态为销售中
        vm.prank(organizer);
        eventManager.updateEventStatus(
            eventId,
            EventManager.EventStatus.ONSALE
        );

        // 快进时间到销售开始
        vm.warp(block.timestamp + 1 hours + 1);

        // 购买门票
        uint256[] memory seatNumbers = new uint256[](0); // 空座位号数组

        vm.prank(buyer);
        eventManager.purchaseTickets(eventId, ticketTypeId, 2, seatNumbers);

        // 验证票种销售数量更新
        (, , , , uint256 sold, , , , , ) = eventManager.getTicketTypeInfo(
            eventId,
            ticketTypeId
        );
        assertEq(sold, 2);
    }

    function test_PurchaseTicketsWithEth() public {
        // 创建活动和票种
        _createEventWithTicketType();

        // 更新活动状态为销售中
        vm.prank(organizer);
        eventManager.updateEventStatus(
            eventId,
            EventManager.EventStatus.ONSALE
        );

        // 快进时间到销售开始
        vm.warp(block.timestamp + 1 hours + 1);

        // 购买门票
        uint256[] memory seatNumbers = new uint256[](0);

        vm.prank(buyer);
        eventManager.purchaseTicketsWithEth{value: ETH_TICKET_PRICE * 2}(
            eventId,
            ticketTypeId,
            2,
            seatNumbers
        );

        // 验证票种销售数量更新
        (, , , , uint256 sold, , , , , ) = eventManager.getTicketTypeInfo(
            eventId,
            ticketTypeId
        );
        assertEq(sold, 2);
    }

    function test_UpdateEventStatus() public {
        // 创建活动
        vm.prank(organizer);
        eventId = eventManager.createEvent(
            "Test Concert",
            "A great concert",
            "",
            "Test Venue",
            startTime,
            endTime,
            false
        );

        // 更新状态为预售中
        vm.prank(organizer);
        eventManager.updateEventStatus(
            eventId,
            EventManager.EventStatus.PRESALE
        );

        // 验证状态更新
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            EventManager.EventStatus status,
            ,
            ,
            ,
            ,
            ,

        ) = eventManager.getEventInfo(eventId);
        assertTrue(status == EventManager.EventStatus.PRESALE);
    }

    function test_WithdrawRevenue() public {
        // 创建活动和票种并购买
        _createEventWithTicketType();

        vm.prank(organizer);
        eventManager.updateEventStatus(
            eventId,
            EventManager.EventStatus.ONSALE
        );

        vm.warp(block.timestamp + 1 hours + 1);

        uint256[] memory seatNumbers = new uint256[](0);
        vm.prank(buyer);
        eventManager.purchaseTickets(eventId, ticketTypeId, 1, seatNumbers);

        // 主办方提取收入
        uint256 organizerBalanceBefore = platformToken.balanceOf(organizer);

        vm.prank(organizer);
        eventManager.withdrawRevenue(false); // 提取代币收入

        // 验证余额变化
        uint256 organizerBalanceAfter = platformToken.balanceOf(organizer);
        assertTrue(organizerBalanceAfter > organizerBalanceBefore);
    }

    function test_PauseFunctionality() public {
        eventManager.pause();
        assertTrue(eventManager.paused());

        eventManager.unpause();
        assertFalse(eventManager.paused());
    }

    function test_SetFeeRates() public {
        uint256 newOrganizerFeeRate = 600; // 6%
        uint256 newPlatformFeeRate = 300; // 3%

        eventManager.setDefaultOrganizerFeeRate(newOrganizerFeeRate);
        assertEq(eventManager.defaultOrganizerFeeRate(), newOrganizerFeeRate);

        eventManager.setPlatformFeeRate(newPlatformFeeRate);
        assertEq(eventManager.platformFeeRate(), newPlatformFeeRate);
    }

    // ============ 错误情况测试 ============

    function test_CreateEventUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("EventManager: not authorized organizer");
        eventManager.createEvent(
            "Test Concert",
            "A great concert",
            "",
            "Test Venue",
            startTime,
            endTime,
            false
        );
    }

    function test_PurchaseNonexistentTicketType() public {
        _createEventWithTicketType();

        vm.prank(organizer);
        eventManager.updateEventStatus(
            eventId,
            EventManager.EventStatus.ONSALE
        );

        vm.warp(block.timestamp + 1 hours + 1);

        uint256[] memory seatNumbers = new uint256[](0);

        vm.prank(buyer);
        vm.expectRevert("EventManager: invalid ticket type");
        eventManager.purchaseTickets(eventId, 999, 1, seatNumbers);
    }

    function test_OnlyOwnerFunctions() public {
        vm.prank(organizer);
        vm.expectRevert();
        eventManager.setDefaultOrganizerFeeRate(600);

        vm.prank(organizer);
        vm.expectRevert();
        eventManager.pause();
    }

    // ============ 辅助函数 ============

    function _createEventWithTicketType() internal {
        // 创建活动
        vm.prank(organizer);
        eventId = eventManager.createEvent(
            "Test Concert",
            "A great concert",
            "",
            "Test Venue",
            startTime,
            endTime,
            false
        );

        // 添加票种
        vm.prank(organizer);
        ticketTypeId = eventManager.addTicketType(
            eventId,
            "VIP Ticket",
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            TICKET_SUPPLY,
            block.timestamp, // 预售开始时间
            block.timestamp + 1 hours, // 正式销售开始时间
            startTime - 1 hours, // 销售结束时间
            true, // 可转让
            false // 非仅预售
        );
    }
}
