// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TicketManager.sol";
import "./EventManager.sol";

/**
 * @title Marketplace
 * @dev 门票二级市场交易合约
 * @notice 处理门票的上架、购买、竞拍等二级市场交易功能
 */
contract Marketplace is Ownable, ReentrancyGuard, Pausable, IERC721Receiver {
    // ============ 状态变量 ============

    TicketManager public immutable ticketManager;
    EventManager public immutable eventManager;
    IERC20 public immutable platformToken;

    uint256 private _nextListingId;
    uint256 private _nextAuctionId;

    // 交易类型枚举
    enum ListingType {
        FIXED_PRICE, // 固定价格
        AUCTION // 拍卖
    }

    // 上架状态枚举
    enum ListingStatus {
        ACTIVE, // 活跃
        SOLD, // 已售出
        CANCELLED, // 已取消
        EXPIRED // 已过期
    }

    // 拍卖状态枚举
    enum AuctionStatus {
        ACTIVE, // 进行中
        ENDED, // 已结束
        CANCELLED // 已取消
    }

    // 固定价格上架结构
    struct Listing {
        uint256 listingId; // 上架ID
        uint256 tokenId; // 门票ID
        address seller; // 卖家
        uint256 price; // 价格（平台代币）
        uint256 ethPrice; // ETH价格（可选）
        uint256 createdAt; // 创建时间
        uint256 expiresAt; // 过期时间
        ListingStatus status; // 状态
        bool acceptsEth; // 是否接受ETH支付
    }

    // 拍卖结构
    struct Auction {
        uint256 auctionId; // 拍卖ID
        uint256 tokenId; // 门票ID
        address seller; // 卖家
        uint256 startingPrice; // 起拍价（平台代币）
        uint256 ethStartingPrice; // ETH起拍价（可选）
        uint256 reservePrice; // 保留价
        uint256 currentBid; // 当前最高出价
        address currentBidder; // 当前最高出价者
        uint256 startTime; // 开始时间
        uint256 endTime; // 结束时间
        AuctionStatus status; // 状态
        bool acceptsEth; // 是否接受ETH出价
        bool isEthBid; // 当前最高出价是否为ETH
    }

    // 出价结构
    struct Bid {
        address bidder; // 出价者
        uint256 amount; // 出价金额
        uint256 timestamp; // 出价时间
        bool isEth; // 是否为ETH出价
    }

    // ============ 映射和存储 ============

    // 上架映射
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256) public tokenToListing; // 门票ID -> 上架ID

    // 拍卖映射
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public tokenToAuction; // 门票ID -> 拍卖ID
    mapping(uint256 => Bid[]) public auctionBids; // 拍卖ID -> 出价历史

    // 用户相关
    mapping(address => uint256[]) public userListings; // 用户上架列表
    mapping(address => uint256[]) public userAuctions; // 用户拍卖列表
    mapping(address => uint256) public userBidBalance; // 用户出价资金池（平台代币）
    mapping(address => uint256) public userEthBidBalance; // 用户ETH出价资金池

    // 市场设置
    uint256 public platformFeeRate = 250; // 平台手续费率 2.5%
    uint256 public minListingDuration = 1 hours; // 最小上架时长
    uint256 public maxListingDuration = 30 days; // 最大上架时长
    uint256 public minAuctionDuration = 1 hours; // 最小拍卖时长
    uint256 public maxAuctionDuration = 7 days; // 最大拍卖时长
    uint256 public auctionExtensionTime = 10 minutes; // 拍卖延时时间

    // 收入统计
    uint256 public totalPlatformFees; // 平台总手续费（平台代币）
    uint256 public totalEthPlatformFees; // 平台总ETH手续费

    // ============ 事件 ============

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

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        bool isEth
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid,
        bool isEthBid
    );

    event AuctionCancelled(uint256 indexed auctionId);

    event BidBalanceDeposited(address indexed user, uint256 amount, bool isEth);
    event BidBalanceWithdrawn(address indexed user, uint256 amount, bool isEth);

    // ============ 修饰符 ============

    modifier listingExists(uint256 listingId) {
        require(
            listingId > 0 && listingId < _nextListingId,
            "Marketplace: listing does not exist"
        );
        _;
    }

    modifier auctionExists(uint256 auctionId) {
        require(
            auctionId > 0 && auctionId < _nextAuctionId,
            "Marketplace: auction does not exist"
        );
        _;
    }

    modifier onlyTicketOwner(uint256 tokenId) {
        require(
            ticketManager.ownerOf(tokenId) == msg.sender,
            "Marketplace: not ticket owner"
        );
        _;
    }

    modifier onlyActiveListing(uint256 listingId) {
        require(
            listings[listingId].status == ListingStatus.ACTIVE,
            "Marketplace: listing not active"
        );
        _;
    }

    modifier onlyActiveAuction(uint256 auctionId) {
        require(
            auctions[auctionId].status == AuctionStatus.ACTIVE,
            "Marketplace: auction not active"
        );
        _;
    }

    // ============ 构造函数 ============

    constructor(
        address initialOwner,
        address _ticketManager,
        address _eventManager,
        address _platformToken
    ) Ownable(initialOwner) {
        require(
            _ticketManager != address(0),
            "Marketplace: invalid ticket manager"
        );
        require(
            _eventManager != address(0),
            "Marketplace: invalid event manager"
        );
        require(
            _platformToken != address(0),
            "Marketplace: invalid platform token"
        );

        ticketManager = TicketManager(_ticketManager);
        eventManager = EventManager(payable(_eventManager));
        platformToken = IERC20(_platformToken);

        _nextListingId = 1;
        _nextAuctionId = 1;
    }

    // ============ 平台设置 ============

    /**
     * @dev 设置平台手续费率
     */
    function setPlatformFeeRate(uint256 feeRate) external onlyOwner {
        require(feeRate <= 1000, "Marketplace: fee rate too high"); // 最大10%
        platformFeeRate = feeRate;
    }

    /**
     * @dev 设置上架时长限制
     */
    function setListingDurationLimits(
        uint256 minDuration,
        uint256 maxDuration
    ) external onlyOwner {
        require(
            minDuration < maxDuration,
            "Marketplace: invalid duration limits"
        );
        minListingDuration = minDuration;
        maxListingDuration = maxDuration;
    }

    /**
     * @dev 设置拍卖时长限制
     */
    function setAuctionDurationLimits(
        uint256 minDuration,
        uint256 maxDuration,
        uint256 extensionTime
    ) external onlyOwner {
        require(
            minDuration < maxDuration,
            "Marketplace: invalid duration limits"
        );
        minAuctionDuration = minDuration;
        maxAuctionDuration = maxDuration;
        auctionExtensionTime = extensionTime;
    }

    // ============ 固定价格交易 ============

    /**
     * @dev 创建固定价格上架
     */
    function createListing(
        uint256 tokenId,
        uint256 price,
        uint256 ethPrice,
        uint256 duration,
        bool acceptsEth
    )
        external
        onlyTicketOwner(tokenId)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(price > 0 || ethPrice > 0, "Marketplace: invalid price");
        require(
            duration >= minListingDuration && duration <= maxListingDuration,
            "Marketplace: invalid duration"
        );
        require(
            tokenToListing[tokenId] == 0,
            "Marketplace: ticket already listed"
        );
        require(tokenToAuction[tokenId] == 0, "Marketplace: ticket in auction");

        // 验证门票可转让性
        _validateTicketTransferable(tokenId);

        // 转移门票到合约
        ticketManager.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 listingId = _nextListingId++;
        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            ethPrice: ethPrice,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            status: ListingStatus.ACTIVE,
            acceptsEth: acceptsEth
        });

        tokenToListing[tokenId] = listingId;
        userListings[msg.sender].push(listingId);

        emit ListingCreated(
            listingId,
            tokenId,
            msg.sender,
            price,
            ethPrice,
            expiresAt
        );

        return listingId;
    }

    /**
     * @dev 更新上架信息
     */
    function updateListing(
        uint256 listingId,
        uint256 newPrice,
        uint256 newEthPrice,
        uint256 newDuration
    )
        external
        listingExists(listingId)
        onlyActiveListing(listingId)
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Marketplace: not seller");
        require(newPrice > 0 || newEthPrice > 0, "Marketplace: invalid price");

        listing.price = newPrice;
        listing.ethPrice = newEthPrice;

        if (newDuration > 0) {
            require(
                newDuration >= minListingDuration &&
                    newDuration <= maxListingDuration,
                "Marketplace: invalid duration"
            );
            listing.expiresAt = block.timestamp + newDuration;
        }

        emit ListingUpdated(
            listingId,
            newPrice,
            newEthPrice,
            listing.expiresAt
        );
    }

    /**
     * @dev 取消上架
     */
    function cancelListing(
        uint256 listingId
    )
        external
        listingExists(listingId)
        onlyActiveListing(listingId)
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Marketplace: not seller");

        listing.status = ListingStatus.CANCELLED;
        tokenToListing[listing.tokenId] = 0;

        // 返还门票给卖家
        ticketManager.safeTransferFrom(
            address(this),
            listing.seller,
            listing.tokenId
        );

        emit ListingCancelled(listingId);
    }

    /**
     * @dev 购买门票（使用平台代币）
     */
    function buyTicket(
        uint256 listingId
    )
        external
        listingExists(listingId)
        onlyActiveListing(listingId)
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = listings[listingId];
        require(listing.price > 0, "Marketplace: token payment not supported");
        require(
            block.timestamp <= listing.expiresAt,
            "Marketplace: listing expired"
        );
        require(
            msg.sender != listing.seller,
            "Marketplace: cannot buy own ticket"
        );

        uint256 totalPrice = listing.price;
        uint256 platformFee = (totalPrice * platformFeeRate) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        // 转账平台代币
        require(
            platformToken.transferFrom(msg.sender, address(this), totalPrice),
            "Marketplace: transfer failed"
        );

        // 分配收入
        totalPlatformFees += platformFee;
        require(
            platformToken.transfer(listing.seller, sellerAmount),
            "Marketplace: seller transfer failed"
        );

        // 转移门票给买家
        ticketManager.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        // 更新状态
        listing.status = ListingStatus.SOLD;
        tokenToListing[listing.tokenId] = 0;

        emit TicketSold(
            listingId,
            listing.tokenId,
            msg.sender,
            listing.seller,
            totalPrice,
            false
        );
    }

    /**
     * @dev 购买门票（使用ETH）
     */
    function buyTicketWithEth(
        uint256 listingId
    )
        external
        payable
        listingExists(listingId)
        onlyActiveListing(listingId)
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = listings[listingId];
        require(
            listing.acceptsEth && listing.ethPrice > 0,
            "Marketplace: ETH payment not supported"
        );
        require(
            block.timestamp <= listing.expiresAt,
            "Marketplace: listing expired"
        );
        require(
            msg.sender != listing.seller,
            "Marketplace: cannot buy own ticket"
        );
        require(
            msg.value >= listing.ethPrice,
            "Marketplace: insufficient payment"
        );

        uint256 totalPrice = listing.ethPrice;
        uint256 platformFee = (totalPrice * platformFeeRate) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        // 退还多余的ETH
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        // 分配收入
        totalEthPlatformFees += platformFee;
        payable(listing.seller).transfer(sellerAmount);

        // 转移门票给买家
        ticketManager.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        // 更新状态
        listing.status = ListingStatus.SOLD;
        tokenToListing[listing.tokenId] = 0;

        emit TicketSold(
            listingId,
            listing.tokenId,
            msg.sender,
            listing.seller,
            totalPrice,
            true
        );
    }

    // ============ 拍卖交易 ============

    /**
     * @dev 创建拍卖
     */
    function createAuction(
        uint256 tokenId,
        uint256 startingPrice,
        uint256 ethStartingPrice,
        uint256 reservePrice,
        uint256 duration,
        bool acceptsEth
    )
        external
        onlyTicketOwner(tokenId)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(
            startingPrice > 0 || ethStartingPrice > 0,
            "Marketplace: invalid starting price"
        );
        require(
            duration >= minAuctionDuration && duration <= maxAuctionDuration,
            "Marketplace: invalid duration"
        );
        require(
            tokenToListing[tokenId] == 0,
            "Marketplace: ticket already listed"
        );
        require(
            tokenToAuction[tokenId] == 0,
            "Marketplace: ticket already in auction"
        );

        // 验证门票可转让性
        _validateTicketTransferable(tokenId);

        // 转移门票到合约
        ticketManager.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 auctionId = _nextAuctionId++;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            tokenId: tokenId,
            seller: msg.sender,
            startingPrice: startingPrice,
            ethStartingPrice: ethStartingPrice,
            reservePrice: reservePrice,
            currentBid: 0,
            currentBidder: address(0),
            startTime: block.timestamp,
            endTime: endTime,
            status: AuctionStatus.ACTIVE,
            acceptsEth: acceptsEth,
            isEthBid: false
        });

        tokenToAuction[tokenId] = auctionId;
        userAuctions[msg.sender].push(auctionId);

        emit AuctionCreated(
            auctionId,
            tokenId,
            msg.sender,
            startingPrice,
            ethStartingPrice,
            reservePrice,
            endTime
        );

        return auctionId;
    }

    // ============ 内部辅助函数 ============

    /**
     * @dev 验证门票可转让性
     */
    function _validateTicketTransferable(uint256 tokenId) internal view {
        TicketManager.TicketMetadata memory ticketInfo = ticketManager
            .getTicketInfo(tokenId);
        require(
            ticketInfo.isTransferable,
            "Marketplace: ticket not transferable"
        );
        require(
            ticketInfo.status == TicketManager.TicketStatus.VALID,
            "Marketplace: invalid ticket status"
        );
        require(
            block.timestamp < ticketInfo.validUntil,
            "Marketplace: ticket expired"
        );
    }

    // ============ 查询功能 ============

    /**
     * @dev 获取上架信息
     */
    function getListingInfo(
        uint256 listingId
    )
        external
        view
        listingExists(listingId)
        returns (
            uint256 tokenId,
            address seller,
            uint256 price,
            uint256 ethPrice,
            uint256 createdAt,
            uint256 expiresAt,
            ListingStatus status,
            bool acceptsEth
        )
    {
        Listing storage listing = listings[listingId];
        return (
            listing.tokenId,
            listing.seller,
            listing.price,
            listing.ethPrice,
            listing.createdAt,
            listing.expiresAt,
            listing.status,
            listing.acceptsEth
        );
    }

    /**
     * @dev 获取用户上架列表
     */
    function getUserListings(
        address user
    ) external view returns (uint256[] memory) {
        return userListings[user];
    }

    /**
     * @dev 获取活跃上架列表
     */
    function getActiveListings(
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory activeListings) {
        require(limit <= 100, "Marketplace: limit too high");

        uint256[] memory result = new uint256[](limit);
        uint256 count = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < _nextListingId && count < limit; i++) {
            if (
                listings[i].status == ListingStatus.ACTIVE &&
                block.timestamp <= listings[i].expiresAt
            ) {
                if (currentIndex >= offset) {
                    result[count] = i;
                    count++;
                }
                currentIndex++;
            }
        }

        // 调整数组大小
        assembly {
            mstore(result, count)
        }

        return result;
    }

    // ============ 管理功能 ============

    /**
     * @dev 清理过期上架
     */
    function cleanupExpiredListings(uint256[] memory listingIds) external {
        for (uint256 i = 0; i < listingIds.length; i++) {
            uint256 listingId = listingIds[i];
            if (listingId > 0 && listingId < _nextListingId) {
                Listing storage listing = listings[listingId];
                if (
                    listing.status == ListingStatus.ACTIVE &&
                    block.timestamp > listing.expiresAt
                ) {
                    listing.status = ListingStatus.EXPIRED;
                    tokenToListing[listing.tokenId] = 0;

                    // 返还门票给卖家
                    ticketManager.safeTransferFrom(
                        address(this),
                        listing.seller,
                        listing.tokenId
                    );
                }
            }
        }
    }

    /**
     * @dev 提取平台手续费
     */
    function withdrawPlatformFees(
        bool isEth,
        uint256 amount
    ) external onlyOwner {
        if (isEth) {
            require(
                amount <= totalEthPlatformFees,
                "Marketplace: insufficient balance"
            );
            totalEthPlatformFees -= amount;
            payable(owner()).transfer(amount);
        } else {
            require(
                amount <= totalPlatformFees,
                "Marketplace: insufficient balance"
            );
            totalPlatformFees -= amount;
            require(
                platformToken.transfer(owner(), amount),
                "Marketplace: transfer failed"
            );
        }
    }

    /**
     * @dev 暂停/恢复合约
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev 紧急提取合约中的代币
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Marketplace: withdraw to zero address");

        if (token == address(0)) {
            // 提取ETH
            payable(to).transfer(amount);
        } else {
            // 提取ERC20代币
            IERC20(token).transfer(to, amount);
        }
    }

    /**
     * @dev 实现IERC721Receiver接口
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev 支持接收ETH
     */
    receive() external payable {}
}
