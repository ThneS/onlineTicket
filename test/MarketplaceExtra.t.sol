// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/TicketManager.sol";
import "../src/PlatformToken.sol";
import "../src/EventManager.sol";

contract MarketplaceExtraTest is Test {
    Marketplace marketplace;
    TicketManager ticketManager;
    PlatformToken platformToken;
    EventManager eventManager;

    address owner;
    address seller;
    address buyer;
    address buyer2;
    address minter;

    uint256 tokenId1;
    uint256 tokenId2;

    uint256 constant EVENT_ID = 10;
    uint256 constant LISTING_DURATION = 2 hours;
    uint256 constant TICKET_PRICE = 1000e18;
    uint256 constant ETH_TICKET_PRICE = 1 ether;

    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");
        minter = makeAddr("minter");

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

        ticketManager.setMinterAuthorization(minter, true);

        platformToken.mint(seller, 2_000_000e18);
        platformToken.mint(buyer, 2_000_000e18);
        platformToken.mint(buyer2, 2_000_000e18);

        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);

        vm.startPrank(minter);
        tokenId1 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            1,
            TICKET_PRICE,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP",
            "uri1"
        );
        tokenId2 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            2,
            TICKET_PRICE,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP",
            "uri2"
        );
        vm.stopPrank();

        vm.prank(seller);
        ticketManager.setApprovalForAll(address(marketplace), true);

        vm.prank(buyer);
        platformToken.approve(address(marketplace), type(uint256).max);
        vm.prank(buyer2);
        platformToken.approve(address(marketplace), type(uint256).max);
    }

    // 允许本测试合约接收 ETH，用于提现测试
    receive() external payable {}

    function _listToken1() internal returns (uint256) {
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

    function test_DuplicateListingRevert() public {
        uint256 id = _listToken1();
        assertGt(id, 0);
        vm.prank(seller);
        // 再次上架时，门票已在合约中，卖家不再是 owner，先触发 not ticket owner
        vm.expectRevert("Marketplace: not ticket owner");
        marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );
    }

    function test_ListThenCancelNotOwnerRevert() public {
        uint256 id = _listToken1();
        vm.prank(buyer);
        vm.expectRevert("Marketplace: not seller");
        marketplace.cancelListing(id);
    }

    function test_BuyWrongPaymentMethodRevert() public {
        uint256 id;
        // list only token payment
        vm.prank(seller);
        id = marketplace.createListing(
            tokenId1,
            TICKET_PRICE,
            0,
            LISTING_DURATION,
            false
        );

        // try buy with ETH
        vm.prank(buyer);
        vm.expectRevert("Marketplace: ETH payment not supported");
        marketplace.buyTicketWithEth{value: ETH_TICKET_PRICE}(id);

        // list only eth payment
        vm.prank(minter); // mint new ticket to seller
        uint256 tokenId3 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            3,
            TICKET_PRICE,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP",
            "uri3"
        );
        vm.prank(seller);
        ticketManager.approve(address(marketplace), tokenId3);
        vm.prank(seller);
        uint256 id2 = marketplace.createListing(
            tokenId3,
            0,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        // try buy with token
        vm.prank(buyer);
        vm.expectRevert("Marketplace: token payment not supported");
        marketplace.buyTicket(id2);
    }

    function test_ListingExpiryAndCleanup() public {
        uint256 id = _listToken1();
        // fast forward after expiry
        vm.warp(block.timestamp + LISTING_DURATION + 1);

        // buy should revert expired
        vm.prank(buyer);
        vm.expectRevert("Marketplace: listing expired");
        marketplace.buyTicket(id);

        // cleanup
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        marketplace.cleanupExpiredListings(ids);

        // token should return to seller
        assertEq(ticketManager.ownerOf(tokenId1), seller);
    }

    function test_GetActiveListingsPagination() public {
        // create multiple listings
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(minter);
            uint256 newId = ticketManager.mintTicket(
                seller,
                EVENT_ID,
                10 + i,
                TICKET_PRICE,
                1,
                block.timestamp,
                block.timestamp + 30 days,
                true,
                "VIP",
                string(abi.encodePacked("uri-", vm.toString(i)))
            );
            vm.prank(seller);
            ticketManager.approve(address(marketplace), newId);
            vm.prank(seller);
            marketplace.createListing(
                newId,
                TICKET_PRICE,
                0,
                LISTING_DURATION,
                false
            );
        }
        uint256[] memory firstPage = marketplace.getActiveListings(0, 3);
        assertEq(firstPage.length, 3);
        uint256[] memory secondPage = marketplace.getActiveListings(3, 3);
        assertTrue(secondPage.length >= 1);
    }

    function test_WithdrawPlatformFeesTokenAndEth() public {
        uint256 id = _listToken1();
        // buyer purchases with token
        vm.prank(buyer);
        marketplace.buyTicket(id);
        uint256 feesToken = marketplace.totalPlatformFees();
        assertGt(feesToken, 0);
        uint256 ownerTokenBefore = platformToken.balanceOf(owner);
        marketplace.withdrawPlatformFees(false, feesToken / 2);
        assertEq(
            platformToken.balanceOf(owner),
            ownerTokenBefore + feesToken / 2
        );

        // new listing accepts ETH
        vm.prank(minter);
        uint256 tokenId3 = ticketManager.mintTicket(
            seller,
            EVENT_ID,
            99,
            TICKET_PRICE,
            1,
            block.timestamp,
            block.timestamp + 30 days,
            true,
            "VIP",
            "uri-fee"
        );
        vm.prank(seller);
        ticketManager.approve(address(marketplace), tokenId3);
        vm.prank(seller);
        uint256 id2 = marketplace.createListing(
            tokenId3,
            0,
            ETH_TICKET_PRICE,
            LISTING_DURATION,
            true
        );

        vm.prank(buyer2);
        marketplace.buyTicketWithEth{value: ETH_TICKET_PRICE}(id2);
        uint256 feesEth = marketplace.totalEthPlatformFees();
        assertGt(feesEth, 0);
        uint256 ownerEthBefore = owner.balance;
        marketplace.withdrawPlatformFees(true, feesEth / 2);
        assertEq(owner.balance, ownerEthBefore + feesEth / 2);
    }
}
