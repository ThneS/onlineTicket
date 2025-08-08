// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/TicketManager.sol";
import "../src/PlatformToken.sol";
import "../src/EventManager.sol";

/**
 * @title MarketplaceTest
 * @dev Marketplace合约的完整测试套件
 */
contract MarketplaceTest is Test {
    // 合约实例
    Marketplace public marketplace;
    TicketManager public ticketManager;
    PlatformToken public platformToken;
    EventManager public eventManager;

    // 测试账户
    address public owner;
    address public seller;
    address public buyer;
    address public buyer2;
    address public minter;
    address public verifier;

    // 测试常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000e18;
    uint256 public constant TICKET_PRICE = 1000e18;
    uint256 public constant ETH_TICKET_PRICE = 1 ether;
    uint256 public constant PLATFORM_FEE_RATE = 250; // 2.5%
    uint256 public constant EVENT_ID = 1;
    uint256 public constant SEAT_NUMBER = 101;
    uint256 public constant LISTING_DURATION = 1 days;
    uint256 public constant AUCTION_DURATION = 1 hours;

    // 测试数据
    uint256 public tokenId1;
    uint256 public tokenId2;
    uint256 public validFrom;
    uint256 public validUntil;

    // 事件定义
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price,
        uint256 ethPrice,
        uint256 expiresAt
    );

    event ListingUpdated(
        uint256 indexed listingId,
        uint256 newPrice,
        uint256 newEthPrice,
        uint256 newExpiresAt
    );

    event ListingCancelled(uint256 indexed listingId);

    event TicketSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price,
        bool paidWithEth
    );

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 startingPrice,
        uint256 ethStartingPrice,
        uint256 reservePrice,
        uint256 endTime
    );

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");
        minter = makeAddr("minter");
        verifier = makeAddr("verifier");

        // 部署合约
        platformToken = new PlatformToken(owner);
        ticketManager = new TicketManager(owner);
        eventManager = new EventManager(
            owner,
            address(ticketManager),
            address(platformToken)
        );

        marketplace = new Marketplace(
            owner,
            address(ticketManager),
            address(eventManager),
            address(platformToken)
        );

        // 设置时间
        validFrom = block.timestamp;
        validUntil = block.timestamp + 30 days;

        // 设置权限
        ticketManager.setMinterAuthorization(minter, true);
        ticketManager.setVerifierAuthorization(verifier, true);

        // 为测试用户分发代币
        platformToken.mint(seller, INITIAL_SUPPLY);
        platformToken.mint(buyer, INITIAL_SUPPLY);
        platformToken.mint(buyer2, INITIAL_SUPPLY);

        // 为测试用户提供ETH
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);

        // 铸造测试门票
        vm.prank(minter);
        tokenId1 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            SEAT_NUMBER,
            TICKET_PRICE,
            1, // category
            validFrom,
            validUntil,
            true, // transferable
            "VIP",
            "https://example.com/ticket/1"
        );

        vm.prank(minter);
        tokenId2 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            SEAT_NUMBER + 1,
            TICKET_PRICE,
            1, // category
            validFrom,
            validUntil,
            true, // transferable
            "VIP",
            "https://example.com/ticket/2"
        );

        // 卖家授权marketplace操作门票
        vm.prank(seller);
        ticketManager.setApprovalForAll(address(marketplace), true);

        // 买家授权marketplace操作代币
        vm.prank(buyer);
        platformToken.approve(address(marketplace), type(uint256).max);
        vm.prank(buyer2);
        platformToken.approve(address(marketplace), type(uint256).max);
    }

    // ============ 部署和初始化测试 ============

    function test_Deployment() public view {
        assertEq(address(marketplace.ticketManager()), address(ticketManager));
        assertEq(address(marketplace.eventManager()), address(eventManager));
        assertEq(address(marketplace.platformToken()), address(platformToken));
        assertEq(marketplace.owner(), owner);
        assertEq(marketplace.platformFeeRate(), PLATFORM_FEE_RATE);
        assertEq(marketplace.minListingDuration(), 1 hours);
        assertEq(marketplace.maxListingDuration(), 30 days);
    }

    function test_DeploymentWithZeroAddresses() public {
        vm.expectRevert("Marketplace: invalid ticket manager");
        new Marketplace(
            owner,
            address(0),
            address(eventManager),
            address(platformToken)
        );

        vm.expectRevert("Marketplace: invalid event manager");
        new Marketplace(
            owner,
            address(ticketManager),
            address(0),
            address(platformToken)
        );

        vm.expectRevert("Marketplace: invalid platform token");
        new Marketplace(
            owner,
            address(ticketManager),
            address(eventManager),
            address(0)
        );
    }

    // ============ 平台设置测试 ============

    function test_SetPlatformFeeRate() public {
        uint256 newFeeRate = 300; // 3%
        marketplace.setPlatformFeeRate(newFeeRate);
        assertEq(marketplace.platformFeeRate(), newFeeRate);
    }

    function test_SetPlatformFeeRateTooHigh() public {
        vm.expectRevert("Marketplace: fee rate too high");
        marketplace.setPlatformFeeRate(1001); // > 10%
    }

    function test_SetPlatformFeeRateOnlyOwner() public {
        vm.prank(seller);
        vm.expectRevert();
        marketplace.setPlatformFeeRate(300);
    }

    function test_SetListingDurationLimits() public {
        uint256 newMinDuration = 30 minutes;
        uint256 newMaxDuration = 60 days;

        marketplace.setListingDurationLimits(newMinDuration, newMaxDuration);

        assertEq(marketplace.minListingDuration(), newMinDuration);
        assertEq(marketplace.maxListingDuration(), newMaxDuration);
    }

    function test_SetListingDurationLimitsInvalid() public {
        vm.expectRevert("Marketplace: invalid duration limits");
        marketplace.setListingDurationLimits(2 hours, 1 hours); // min > max
    }

    function test_SetAuctionDurationLimits() public {
        uint256 newMinDuration = 30 minutes;
        uint256 newMaxDuration = 14 days;
        uint256 newExtensionTime = 15 minutes;

        marketplace.setAuctionDurationLimits(
            newMinDuration,
            newMaxDuration,
            newExtensionTime
        );

        assertEq(marketplace.minAuctionDuration(), newMinDuration);
        assertEq(marketplace.maxAuctionDuration(), newMaxDuration);
        assertEq(marketplace.auctionExtensionTime(), newExtensionTime);
    }

    // ============ 固定价格上架测试 ============

    function test_CreateListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 验证上架信息
        (
            uint256 tokenId,
            address listedSeller,
            uint256 price,
            uint256 ethPrice,
            uint256 createdAt,
            uint256 expiresAt,
            Marketplace.ListingStatus status,
            bool acceptsEth
        ) = marketplace.getListingInfo(listingId);

        assertEq(tokenId, tokenId1);
        assertEq(listedSeller, seller);
        assertEq(price, TICKET_PRICE);
        assertEq(ethPrice, ETH_TICKET_PRICE);
        assertEq(createdAt, block.timestamp);
        assertEq(expiresAt, block.timestamp + LISTING_DURATION);
        assertTrue(status == Marketplace.ListingStatus.ACTIVE);
        assertTrue(acceptsEth);

        // 验证门票已转移到合约
        assertEq(ticketManager.ownerOf(tokenId1), address(marketplace));

        // 验证映射关系
        assertEq(marketplace.tokenToListing(tokenId1), listingId);

        // 验证用户上架列表
        uint256[] memory userListings = marketplace.getUserListings(seller);
        assertEq(userListings.length, 1);
        assertEq(userListings[0], listingId);
    }

    function test_CreateListingEmitEvent() public {
        uint256 expectedExpiresAt = block.timestamp + LISTING_DURATION;

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(
            1,
            tokenId1,
            seller,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            expectedExpiresAt
        );

        vm.prank(seller);
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    function test_CreateListingNotOwner() public {
        vm.prank(buyer);
        vm.expectRevert("Marketplace: not ticket owner");
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    function test_CreateListingInvalidPrice() public {
        vm.prank(seller);
        vm.expectRevert("Marketplace: invalid price");
        marketplace.createListing(tokenId1, 0, 0, LISTING_DURATION, true);
    }

    function test_CreateListingInvalidDuration() public {
        vm.prank(seller);
        vm.expectRevert("Marketplace: invalid duration");
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            30 minutes, // 小于最小时长
            true
        );

        vm.prank(seller);
        vm.expectRevert("Marketplace: invalid duration");
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            31 days, // 大于最大时长
            true
        );
    }

    function test_CreateListingAlreadyListed() public {
        vm.startPrank(seller);
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 尝试再次上架同一门票 - 但卖家已经不拥有门票了，所以会出现"not ticket owner"错误
        vm.expectRevert("Marketplace: not ticket owner");
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE * 2,
            ETH_TICKET_PRICE * 2,
            LISTING_DURATION,
            true
        );
        vm.stopPrank();
    }

    function test_CreateListingWhenPaused() public {
        marketplace.pause();

        vm.prank(seller);
        vm.expectRevert();
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    // ============ 上架更新测试 ============

    function test_UpdateListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        uint256 newPrice = TICKET_PRICE * 2;
        uint256 newEthPrice = ETH_TICKET_PRICE * 2;
        uint256 newDuration = LISTING_DURATION * 2;

        vm.expectEmit(true, true, true, true);
        emit ListingUpdated(
            listingId,
            newPrice,
            newEthPrice,
            block.timestamp + newDuration
        );

        vm.prank(seller);
        marketplace.updateListing(
            listingId,
            newPrice,
            newEthPrice,
            newDuration
        );

        // 验证更新
        (
            ,
            ,
            uint256 price,
            uint256 ethPrice,
            ,
            uint256 expiresAt,
            ,

        ) = marketplace.getListingInfo(listingId);

        assertEq(price, newPrice);
        assertEq(ethPrice, newEthPrice);
        assertEq(expiresAt, block.timestamp + newDuration);
    }

    function test_UpdateListingNotSeller() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer);
        vm.expectRevert("Marketplace: not seller");
        marketplace.updateListing(
            listingId,
            TICKET_PRICE * 2,
            ETH_TICKET_PRICE * 2,
            0
        );
    }

    function test_UpdateListingInvalidPrice() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(seller);
        vm.expectRevert("Marketplace: invalid price");
        marketplace.updateListing(listingId, 0, 0, 0);
    }

    function test_UpdateListingNonexistent() public {
        vm.prank(seller);
        vm.expectRevert("Marketplace: listing does not exist");
        marketplace.updateListing(999, TICKET_PRICE, ETH_TICKET_PRICE, 0);
    }

    // ============ 取消上架测试 ============

    function test_CancelListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.expectEmit(true, true, true, true);
        emit ListingCancelled(listingId);

        vm.prank(seller);
        marketplace.cancelListing(listingId);

        // 验证状态更新
        (, , , , , , Marketplace.ListingStatus status, ) = marketplace
            .getListingInfo(listingId);
        assertTrue(status == Marketplace.ListingStatus.CANCELLED);

        // 验证门票归还
        assertEq(ticketManager.ownerOf(tokenId1), seller);

        // 验证映射清除
        assertEq(marketplace.tokenToListing(tokenId1), 0);
    }

    function test_CancelListingNotSeller() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer);
        vm.expectRevert("Marketplace: not seller");
        marketplace.cancelListing(listingId);
    }

    // ============ 门票购买测试 ============

    function test_BuyTicketWithToken() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        uint256 platformFee = (TICKET_PRICE * PLATFORM_FEE_RATE) / 10000;
        uint256 sellerAmount = TICKET_PRICE - platformFee;

        uint256 buyerBalanceBefore = platformToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = platformToken.balanceOf(seller);
        uint256 marketplaceFeesBefore = marketplace.totalPlatformFees();

        vm.expectEmit(true, true, true, true);
        emit TicketSold(
            listingId,
            tokenId1,
            buyer,
            seller,
            TICKET_PRICE,
            false
        );

        vm.prank(buyer);
        marketplace.buyTicket(listingId);

        // 验证代币转移
        assertEq(
            platformToken.balanceOf(buyer),
            buyerBalanceBefore - TICKET_PRICE
        );
        assertEq(
            platformToken.balanceOf(seller),
            sellerBalanceBefore + sellerAmount
        );
        assertEq(
            marketplace.totalPlatformFees(),
            marketplaceFeesBefore + platformFee
        );

        // 验证门票转移
        assertEq(ticketManager.ownerOf(tokenId1), buyer);

        // 验证上架状态
        (, , , , , , Marketplace.ListingStatus status, ) = marketplace
            .getListingInfo(listingId);
        assertTrue(status == Marketplace.ListingStatus.SOLD);
    }

    function test_BuyTicketWithEth() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        uint256 platformFee = (ETH_TICKET_PRICE * PLATFORM_FEE_RATE) / 10000;
        uint256 sellerAmount = ETH_TICKET_PRICE - platformFee;

        uint256 buyerEthBefore = buyer.balance;
        uint256 sellerEthBefore = seller.balance;
        uint256 marketplaceEthFeesBefore = marketplace.totalEthPlatformFees();

        vm.expectEmit(true, true, true, true);
        emit TicketSold(
            listingId,
            tokenId1,
            buyer,
            seller,
            ETH_TICKET_PRICE,
            true
        );

        vm.prank(buyer);
        marketplace.buyTicketWithEth{value: ETH_TICKET_PRICE}(listingId);

        // 验证ETH转移
        assertEq(buyer.balance, buyerEthBefore - ETH_TICKET_PRICE);
        assertEq(seller.balance, sellerEthBefore + sellerAmount);
        assertEq(
            marketplace.totalEthPlatformFees(),
            marketplaceEthFeesBefore + platformFee
        );

        // 验证门票转移
        assertEq(ticketManager.ownerOf(tokenId1), buyer);
    }

    function test_BuyTicketWithEthRefundExcess() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        uint256 excessPayment = 0.5 ether;
        uint256 totalPayment = ETH_TICKET_PRICE + excessPayment;

        uint256 buyerEthBefore = buyer.balance;

        vm.prank(buyer);
        marketplace.buyTicketWithEth{value: totalPayment}(listingId);

        // 验证多余ETH退还
        uint256 expectedBalance = buyerEthBefore - ETH_TICKET_PRICE;
        assertEq(buyer.balance, expectedBalance);
    }

    function test_BuyTicketInsufficientPayment() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 清空buyer的代币余额并取消授权来测试
        vm.startPrank(buyer);
        platformToken.transfer(seller, platformToken.balanceOf(buyer));
        platformToken.approve(address(marketplace), 0);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert();
        marketplace.buyTicket(listingId);
    }

    function test_BuyOwnTicket() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(seller);
        vm.expectRevert("Marketplace: cannot buy own ticket");
        marketplace.buyTicket(listingId);
    }

    function test_BuyExpiredListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 快进时间到过期
        vm.warp(block.timestamp + LISTING_DURATION + 1);

        vm.prank(buyer);
        vm.expectRevert("Marketplace: listing expired");
        marketplace.buyTicket(listingId);
    }

    // ============ 拍卖测试 ============

    function test_CreateAuction() public {
        uint256 startingPrice = TICKET_PRICE / 2;
        uint256 ethStartingPrice = ETH_TICKET_PRICE / 2;
        uint256 reservePrice = TICKET_PRICE;

        vm.expectEmit(true, true, true, true);
        emit AuctionCreated(
            1,
            tokenId1,
            seller,
            startingPrice,
            ethStartingPrice,
            reservePrice,
            block.timestamp + AUCTION_DURATION
        );

        vm.prank(seller);
        uint256 auctionId = marketplace.createAuction(
            tokenId1,
            startingPrice,
            ethStartingPrice,
            reservePrice,
            AUCTION_DURATION,
            true
        );

        // 验证拍卖信息
        (
            uint256 auctionIdReturned,
            uint256 tokenId,
            address auctionSeller,
            uint256 startingPriceReturned,
            uint256 ethStartingPriceReturned,
            uint256 reservePriceReturned,
            uint256 currentBid,
            address currentBidder,
            uint256 startTime,
            uint256 endTime,
            Marketplace.AuctionStatus status,
            bool acceptsEth,
            bool isEthBid
        ) = marketplace.auctions(auctionId);

        assertEq(auctionIdReturned, auctionId);
        assertEq(tokenId, tokenId1);
        assertEq(auctionSeller, seller);
        assertEq(startingPriceReturned, startingPrice);
        assertEq(ethStartingPriceReturned, ethStartingPrice);
        assertEq(reservePriceReturned, reservePrice);
        assertEq(currentBid, 0);
        assertEq(currentBidder, address(0));
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + AUCTION_DURATION);
        assertTrue(status == Marketplace.AuctionStatus.ACTIVE);
        assertTrue(acceptsEth);
        assertFalse(isEthBid);

        // 验证门票已转移到合约
        assertEq(ticketManager.ownerOf(tokenId1), address(marketplace));
    }

    function test_CreateAuctionNotOwner() public {
        vm.prank(buyer);
        vm.expectRevert("Marketplace: not ticket owner");
        marketplace.createAuction(
            tokenId1,
            TICKET_PRICE / 2,
            ETH_TICKET_PRICE / 2,
            TICKET_PRICE,
            AUCTION_DURATION,
            true
        );
    }

    function test_CreateAuctionInvalidStartingPrice() public {
        vm.prank(seller);
        vm.expectRevert("Marketplace: invalid starting price");
        marketplace.createAuction(
            tokenId1,
            0,
            0,
            TICKET_PRICE,
            AUCTION_DURATION,
            true
        );
    }

    // ============ 查询功能测试 ============

    function test_GetActiveListings() public {
        // 创建多个上架
        vm.startPrank(seller);
        uint256 listingId1 = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
        uint256 listingId2 = marketplace.createListing(
            tokenId2,
            TICKET_PRICE * 2,
            ETH_TICKET_PRICE * 2,
            LISTING_DURATION,
            true
        );
        vm.stopPrank();

        uint256[] memory activeListings = marketplace.getActiveListings(0, 10);
        assertEq(activeListings.length, 2);
        assertEq(activeListings[0], listingId1);
        assertEq(activeListings[1], listingId2);
    }

    function test_GetActiveListingsWithOffset() public {
        // 创建多个上架
        vm.startPrank(seller);
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
        uint256 listingId2 = marketplace.createListing(
            tokenId2,
            TICKET_PRICE * 2,
            ETH_TICKET_PRICE * 2,
            LISTING_DURATION,
            true
        );
        vm.stopPrank();

        uint256[] memory activeListings = marketplace.getActiveListings(1, 10);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], listingId2);
    }

    function test_GetActiveListingsLimitTooHigh() public {
        vm.expectRevert("Marketplace: limit too high");
        marketplace.getActiveListings(0, 101);
    }

    // ============ 管理功能测试 ============

    function test_CleanupExpiredListings() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 快进时间到过期
        vm.warp(block.timestamp + LISTING_DURATION + 1);

        uint256[] memory listingIds = new uint256[](1);
        listingIds[0] = listingId;

        marketplace.cleanupExpiredListings(listingIds);

        // 验证状态更新为过期
        (, , , , , , Marketplace.ListingStatus status, ) = marketplace
            .getListingInfo(listingId);
        assertTrue(status == Marketplace.ListingStatus.EXPIRED);

        // 验证门票归还给卖家
        assertEq(ticketManager.ownerOf(tokenId1), seller);
    }

    function test_WithdrawPlatformFeesToken() public {
        // 先创建一笔交易产生手续费
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer);
        marketplace.buyTicket(listingId);

        uint256 platformFee = (TICKET_PRICE * PLATFORM_FEE_RATE) / 10000;
        uint256 ownerBalanceBefore = platformToken.balanceOf(owner);

        // 提取手续费
        marketplace.withdrawPlatformFees(false, platformFee);

        assertEq(
            platformToken.balanceOf(owner),
            ownerBalanceBefore + platformFee
        );
        assertEq(marketplace.totalPlatformFees(), 0);
    }

    function test_WithdrawPlatformFeesEth() public {
        // 先创建一笔ETH交易产生手续费
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer);
        marketplace.buyTicketWithEth{value: ETH_TICKET_PRICE}(listingId);

        uint256 platformFee = (ETH_TICKET_PRICE * PLATFORM_FEE_RATE) / 10000;
        uint256 ownerEthBefore = address(this).balance;

        // 提取ETH手续费
        marketplace.withdrawPlatformFees(true, platformFee);

        assertEq(address(this).balance, ownerEthBefore + platformFee);
        assertEq(marketplace.totalEthPlatformFees(), 0);
    }

    function test_WithdrawPlatformFeesInsufficientBalance() public {
        vm.expectRevert("Marketplace: insufficient balance");
        marketplace.withdrawPlatformFees(false, 1000e18);
    }

    function test_WithdrawPlatformFeesOnlyOwner() public {
        vm.prank(seller);
        vm.expectRevert();
        marketplace.withdrawPlatformFees(false, 100);
    }

    // ============ 暂停功能测试 ============

    function test_PauseUnpause() public {
        // 暂停
        marketplace.pause();
        assertTrue(marketplace.paused());

        // 尝试创建上架应该失败
        vm.prank(seller);
        vm.expectRevert();
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // 恢复
        marketplace.unpause();
        assertFalse(marketplace.paused());

        // 现在应该可以创建上架
        vm.prank(seller);
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    function test_PauseOnlyOwner() public {
        vm.prank(seller);
        vm.expectRevert();
        marketplace.pause();
    }

    // ============ 紧急提取测试 ============

    function test_EmergencyWithdrawEth() public {
        uint256 amount = 1 ether;
        // 先向合约发送一些ETH
        payable(address(marketplace)).transfer(amount);

        uint256 ownerBalanceBefore = owner.balance;
        marketplace.emergencyWithdraw(address(0), owner, amount);

        assertEq(owner.balance, ownerBalanceBefore + amount);
    }

    function test_EmergencyWithdrawToken() public {
        uint256 amount = 1000e18;
        // 先向合约转入一些代币
        platformToken.transfer(address(marketplace), amount);

        uint256 ownerBalanceBefore = platformToken.balanceOf(owner);
        marketplace.emergencyWithdraw(address(platformToken), owner, amount);

        assertEq(platformToken.balanceOf(owner), ownerBalanceBefore + amount);
    }

    function test_EmergencyWithdrawZeroAddress() public {
        vm.expectRevert("Marketplace: withdraw to zero address");
        marketplace.emergencyWithdraw(address(0), address(0), 1000);
    }

    function test_EmergencyWithdrawOnlyOwner() public {
        vm.prank(seller);
        vm.expectRevert();
        marketplace.emergencyWithdraw(address(0), seller, 1000);
    }

    // ============ ERC721Receiver测试 ============

    function test_OnERC721Received() public view {
        bytes4 selector = marketplace.onERC721Received(
            address(0),
            address(0),
            0,
            ""
        );
        assertEq(
            selector,
            bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
        );
    }

    // ============ 接收ETH测试 ============

    function test_ReceiveEth() public {
        uint256 amount = 1 ether;
        uint256 contractBalanceBefore = address(marketplace).balance;

        (bool success, ) = address(marketplace).call{value: amount}("");
        assertTrue(success);

        assertEq(address(marketplace).balance, contractBalanceBefore + amount);
    }

    // ============ 边界条件和错误处理测试 ============

    function test_ListingNonexistentToken() public {
        uint256 nonexistentTokenId = 999;

        vm.prank(seller);
        vm.expectRevert();
        marketplace.createListing(
            nonexistentTokenId,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    function test_BuyNonexistentListing() public {
        vm.expectRevert("Marketplace: listing does not exist");
        marketplace.buyTicket(999);
    }

    function test_GetNonexistentListingInfo() public {
        vm.expectRevert("Marketplace: listing does not exist");
        marketplace.getListingInfo(999);
    }

    // ============ Gas使用测试 ============

    function test_GasUsage_CreateListing() public {
        vm.prank(seller);
        uint256 gasBefore = gasleft();
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
        uint256 gasUsed = gasBefore - gasleft();

        // 记录gas使用情况
        emit log_named_uint("CreateListing Gas Used", gasUsed);
        assertTrue(gasUsed < 500000); // 确保gas使用合理
    }

    function test_GasUsage_BuyTicket() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer);
        uint256 gasBefore = gasleft();
        marketplace.buyTicket(listingId);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("BuyTicket Gas Used", gasUsed);
        assertTrue(gasUsed < 200000);
    }

    // 接收ETH
    receive() external payable {}

    // ============ 辅助函数 ============

    function _createDefaultListing() internal returns (uint256) {
        vm.prank(seller);
        return
            marketplace.createListing(
                tokenId1,
                TICKET_PRICE,
                ETH_TICKET_PRICE,
                LISTING_DURATION,
                true
            );
    }

    function _createDefaultAuction() internal returns (uint256) {
        vm.prank(seller);
        return
            marketplace.createAuction(
                tokenId1,
                TICKET_PRICE / 2,
                ETH_TICKET_PRICE / 2,
                TICKET_PRICE,
                AUCTION_DURATION,
                true
            );
    }
}
