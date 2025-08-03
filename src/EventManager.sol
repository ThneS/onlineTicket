// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TicketManager.sol";

/**
 * @title EventManager
 * @dev 活动管理合约，负责创建和管理各种活动
 * @notice 管理活动的创建、配置、状态管理等核心功能
 */
contract EventManager is Ownable, ReentrancyGuard, Pausable {
    // ============ 状态变量 ============

    uint256 private _nextEventId;
    TicketManager public immutable ticketManager;
    IERC20 public immutable platformToken;

    // 活动状态枚举
    enum EventStatus {
        DRAFT, // 草稿状态
        PUBLISHED, // 已发布
        PRESALE, // 预售中
        ONSALE, // 正式销售中
        SOLD_OUT, // 已售罄
        CANCELLED, // 已取消
        ENDED, // 已结束
        SETTLED // 已结算
    }

    // 票种信息结构
    struct TicketType {
        string name; // 票种名称 (如"VIP票", "普通票")
        uint256 price; // 价格 (平台代币计价)
        uint256 ethPrice; // ETH价格 (可选)
        uint256 totalSupply; // 总供应量
        uint256 sold; // 已售出数量
        uint256 presaleStart; // 预售开始时间
        uint256 saleStart; // 正式销售开始时间
        uint256 saleEnd; // 销售结束时间
        bool isTransferable; // 是否可转让
        bool presaleOnly; // 是否仅预售
        mapping(address => uint256) purchaseLimit; // 用户购买限制
        mapping(address => bool) presaleWhitelist; // 预售白名单
    }

    // 活动信息结构
    struct EventInfo {
        string name; // 活动名称
        string description; // 活动描述
        string imageURI; // 活动图片URI
        string venue; // 举办地点
        address organizer; // 主办方
        uint256 startTime; // 活动开始时间
        uint256 endTime; // 活动结束时间
        EventStatus status; // 活动状态
        uint256 createdAt; // 创建时间
        uint256 totalTicketTypes; // 票种数量
        uint256 totalRevenue; // 总收入(平台代币)
        uint256 totalEthRevenue; // ETH总收入
        uint256 organizerFeeRate; // 主办方手续费率 (基点，如500表示5%)
        bool requiresApproval; // 是否需要审批
        bool isApproved; // 是否已审批
        mapping(uint256 => TicketType) ticketTypes; // 票种映射
    }

    // ============ 映射和存储 ============

    // 活动ID -> 活动信息
    mapping(uint256 => EventInfo) public events;

    // 主办方 -> 活动ID列表
    mapping(address => uint256[]) public organizerEvents;

    // 授权的主办方
    mapping(address => bool) public authorizedOrganizers;

    // 全局默认手续费率 (基点)
    uint256 public defaultOrganizerFeeRate = 500; // 5%

    // 平台手续费率 (基点)
    uint256 public platformFeeRate = 250; // 2.5%

    // 收入池
    mapping(address => uint256) public organizerBalance; // 主办方余额(平台代币)
    mapping(address => uint256) public organizerEthBalance; // 主办方ETH余额
    uint256 public platformBalance; // 平台余额(平台代币)
    uint256 public platformEthBalance; // 平台ETH余额

    // ============ 事件 ============

    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        string name,
        uint256 startTime,
        uint256 endTime
    );

    event EventUpdated(
        uint256 indexed eventId,
        EventStatus oldStatus,
        EventStatus newStatus
    );

    event TicketTypeAdded(
        uint256 indexed eventId,
        uint256 indexed typeId,
        string name,
        uint256 price,
        uint256 totalSupply
    );

    event TicketPurchased(
        uint256 indexed eventId,
        uint256 indexed typeId,
        address indexed buyer,
        uint256 quantity,
        uint256 totalCost,
        bool paidWithEth
    );

    event EventApproved(uint256 indexed eventId, bool approved);

    event OrganizerAuthorized(address indexed organizer, bool authorized);

    event RevenueWithdrawn(
        address indexed organizer,
        uint256 amount,
        bool isEth
    );

    // ============ 修饰符 ============

    modifier eventExists(uint256 eventId) {
        require(
            eventId > 0 && eventId < _nextEventId,
            "EventManager: event does not exist"
        );
        _;
    }

    modifier onlyOrganizer(uint256 eventId) {
        require(
            events[eventId].organizer == msg.sender || msg.sender == owner(),
            "EventManager: not event organizer"
        );
        _;
    }

    modifier onlyAuthorizedOrganizer() {
        require(
            authorizedOrganizers[msg.sender] || msg.sender == owner(),
            "EventManager: not authorized organizer"
        );
        _;
    }

    modifier eventInStatus(uint256 eventId, EventStatus status) {
        require(
            events[eventId].status == status,
            "EventManager: invalid event status"
        );
        _;
    }

    // ============ 构造函数 ============

    constructor(
        address initialOwner,
        address _ticketManager,
        address _platformToken
    ) Ownable(initialOwner) {
        require(
            _ticketManager != address(0),
            "EventManager: invalid ticket manager"
        );
        require(
            _platformToken != address(0),
            "EventManager: invalid platform token"
        );

        ticketManager = TicketManager(_ticketManager);
        platformToken = IERC20(_platformToken);
        _nextEventId = 1;
    }

    // ============ 权限管理 ============

    /**
     * @dev 授权主办方
     */
    function authorizeOrganizer(
        address organizer,
        bool authorized
    ) external onlyOwner {
        authorizedOrganizers[organizer] = authorized;
        emit OrganizerAuthorized(organizer, authorized);
    }

    /**
     * @dev 设置默认手续费率
     */
    function setDefaultOrganizerFeeRate(uint256 feeRate) external onlyOwner {
        require(feeRate <= 10000, "EventManager: fee rate too high"); // 最大100%
        defaultOrganizerFeeRate = feeRate;
    }

    /**
     * @dev 设置平台手续费率
     */
    function setPlatformFeeRate(uint256 feeRate) external onlyOwner {
        require(feeRate <= 1000, "EventManager: platform fee too high"); // 最大10%
        platformFeeRate = feeRate;
    }

    // ============ 活动管理 ============

    /**
     * @dev 创建新活动
     */
    function createEvent(
        string memory name,
        string memory description,
        string memory imageURI,
        string memory venue,
        uint256 startTime,
        uint256 endTime,
        bool requiresApproval
    ) external onlyAuthorizedOrganizer nonReentrant returns (uint256) {
        require(bytes(name).length > 0, "EventManager: empty name");
        require(
            startTime > block.timestamp,
            "EventManager: invalid start time"
        );
        require(endTime > startTime, "EventManager: invalid end time");

        uint256 eventId = _nextEventId++;

        EventInfo storage newEvent = events[eventId];
        newEvent.name = name;
        newEvent.description = description;
        newEvent.imageURI = imageURI;
        newEvent.venue = venue;
        newEvent.organizer = msg.sender;
        newEvent.startTime = startTime;
        newEvent.endTime = endTime;
        newEvent.status = requiresApproval
            ? EventStatus.DRAFT
            : EventStatus.PUBLISHED;
        newEvent.createdAt = block.timestamp;
        newEvent.organizerFeeRate = defaultOrganizerFeeRate;
        newEvent.requiresApproval = requiresApproval;
        newEvent.isApproved = !requiresApproval;

        organizerEvents[msg.sender].push(eventId);

        emit EventCreated(eventId, msg.sender, name, startTime, endTime);

        return eventId;
    }

    /**
     * @dev 更新活动信息
     */
    function updateEvent(
        uint256 eventId,
        string memory name,
        string memory description,
        string memory imageURI,
        string memory venue,
        uint256 startTime,
        uint256 endTime
    ) external eventExists(eventId) onlyOrganizer(eventId) {
        EventInfo storage eventInfo = events[eventId];
        require(
            eventInfo.status == EventStatus.DRAFT ||
                eventInfo.status == EventStatus.PUBLISHED,
            "EventManager: cannot update event in current status"
        );

        if (bytes(name).length > 0) eventInfo.name = name;
        if (bytes(description).length > 0) eventInfo.description = description;
        if (bytes(imageURI).length > 0) eventInfo.imageURI = imageURI;
        if (bytes(venue).length > 0) eventInfo.venue = venue;
        if (startTime > block.timestamp) eventInfo.startTime = startTime;
        if (endTime > startTime) eventInfo.endTime = endTime;
    }

    /**
     * @dev 审批活动
     */
    function approveEvent(
        uint256 eventId,
        bool approved
    ) external onlyOwner eventExists(eventId) {
        EventInfo storage eventInfo = events[eventId];
        require(
            eventInfo.requiresApproval,
            "EventManager: event does not require approval"
        );

        eventInfo.isApproved = approved;
        if (approved && eventInfo.status == EventStatus.DRAFT) {
            EventStatus oldStatus = eventInfo.status;
            eventInfo.status = EventStatus.PUBLISHED;
            emit EventUpdated(eventId, oldStatus, EventStatus.PUBLISHED);
        }

        emit EventApproved(eventId, approved);
    }

    /**
     * @dev 更新活动状态
     */
    function updateEventStatus(
        uint256 eventId,
        EventStatus newStatus
    ) external eventExists(eventId) onlyOrganizer(eventId) {
        EventInfo storage eventInfo = events[eventId];
        EventStatus oldStatus = eventInfo.status;

        require(
            _isValidStatusTransition(oldStatus, newStatus),
            "EventManager: invalid status transition"
        );

        eventInfo.status = newStatus;
        emit EventUpdated(eventId, oldStatus, newStatus);
    }

    /**
     * @dev 检查状态转换是否有效
     */
    function _isValidStatusTransition(
        EventStatus from,
        EventStatus to
    ) internal pure returns (bool) {
        if (from == to) return false;

        // 定义允许的状态转换
        if (from == EventStatus.DRAFT) {
            return to == EventStatus.PUBLISHED || to == EventStatus.CANCELLED;
        }
        if (from == EventStatus.PUBLISHED) {
            return
                to == EventStatus.PRESALE ||
                to == EventStatus.ONSALE ||
                to == EventStatus.CANCELLED;
        }
        if (from == EventStatus.PRESALE) {
            return
                to == EventStatus.ONSALE ||
                to == EventStatus.CANCELLED ||
                to == EventStatus.SOLD_OUT;
        }
        if (from == EventStatus.ONSALE) {
            return
                to == EventStatus.SOLD_OUT ||
                to == EventStatus.ENDED ||
                to == EventStatus.CANCELLED;
        }
        if (from == EventStatus.SOLD_OUT) {
            return to == EventStatus.ENDED || to == EventStatus.CANCELLED;
        }
        if (from == EventStatus.ENDED) {
            return to == EventStatus.SETTLED;
        }

        return false;
    }

    // ============ 票种管理 ============

    /**
     * @dev 添加票种
     */
    function addTicketType(
        uint256 eventId,
        string memory name,
        uint256 price,
        uint256 ethPrice,
        uint256 totalSupply,
        uint256 presaleStart,
        uint256 saleStart,
        uint256 saleEnd,
        bool isTransferable,
        bool presaleOnly
    ) external eventExists(eventId) onlyOrganizer(eventId) returns (uint256) {
        EventInfo storage eventInfo = events[eventId];
        require(
            eventInfo.status == EventStatus.DRAFT ||
                eventInfo.status == EventStatus.PUBLISHED,
            "EventManager: cannot add ticket type in current status"
        );
        require(bytes(name).length > 0, "EventManager: empty ticket type name");
        require(totalSupply > 0, "EventManager: invalid total supply");
        require(saleEnd > saleStart, "EventManager: invalid sale time");

        uint256 typeId = eventInfo.totalTicketTypes++;
        TicketType storage ticketType = eventInfo.ticketTypes[typeId];

        ticketType.name = name;
        ticketType.price = price;
        ticketType.ethPrice = ethPrice;
        ticketType.totalSupply = totalSupply;
        ticketType.sold = 0;
        ticketType.presaleStart = presaleStart;
        ticketType.saleStart = saleStart;
        ticketType.saleEnd = saleEnd;
        ticketType.isTransferable = isTransferable;
        ticketType.presaleOnly = presaleOnly;

        emit TicketTypeAdded(eventId, typeId, name, price, totalSupply);

        return typeId;
    }

    /**
     * @dev 设置票种购买限制
     */
    function setTicketTypePurchaseLimit(
        uint256 eventId,
        uint256 typeId,
        address user,
        uint256 limit
    ) external eventExists(eventId) onlyOrganizer(eventId) {
        require(
            typeId < events[eventId].totalTicketTypes,
            "EventManager: invalid ticket type"
        );
        events[eventId].ticketTypes[typeId].purchaseLimit[user] = limit;
    }

    /**
     * @dev 添加预售白名单
     */
    function addToPresaleWhitelist(
        uint256 eventId,
        uint256 typeId,
        address[] memory users
    ) external eventExists(eventId) onlyOrganizer(eventId) {
        require(
            typeId < events[eventId].totalTicketTypes,
            "EventManager: invalid ticket type"
        );

        TicketType storage ticketType = events[eventId].ticketTypes[typeId];
        for (uint256 i = 0; i < users.length; i++) {
            ticketType.presaleWhitelist[users[i]] = true;
        }
    }

    // ============ 门票购买 ============

    /**
     * @dev 购买门票 (使用平台代币)
     */
    function purchaseTickets(
        uint256 eventId,
        uint256 typeId,
        uint256 quantity,
        uint256[] memory seatNumbers
    ) external eventExists(eventId) nonReentrant whenNotPaused {
        require(quantity > 0, "EventManager: invalid quantity");
        require(
            seatNumbers.length == 0 || seatNumbers.length == quantity,
            "EventManager: seat number mismatch"
        );

        EventInfo storage eventInfo = events[eventId];
        require(eventInfo.isApproved, "EventManager: event not approved");
        require(
            typeId < eventInfo.totalTicketTypes,
            "EventManager: invalid ticket type"
        );

        TicketType storage ticketType = eventInfo.ticketTypes[typeId];

        // 检查销售时间和状态
        _validatePurchaseConditions(eventInfo, ticketType, quantity);

        // 检查库存
        require(
            ticketType.sold + quantity <= ticketType.totalSupply,
            "EventManager: insufficient tickets"
        );

        // 检查购买限制
        uint256 userLimit = ticketType.purchaseLimit[msg.sender];
        if (userLimit > 0) {
            // 这里应该检查用户已购买数量，需要与TicketManager配合
            // 暂时简化处理
        }

        // 计算费用
        uint256 totalCost = ticketType.price * quantity;
        require(totalCost > 0, "EventManager: invalid price");

        // 转账平台代币
        require(
            platformToken.transferFrom(msg.sender, address(this), totalCost),
            "EventManager: transfer failed"
        );

        // 分配收入
        _distributeRevenue(eventInfo.organizer, totalCost, false);

        // 铸造门票NFT
        _mintTickets(eventId, typeId, quantity, seatNumbers, ticketType);

        // 更新状态
        ticketType.sold += quantity;
        eventInfo.totalRevenue += totalCost;

        // 检查是否售罄
        if (_checkSoldOut(eventInfo)) {
            EventStatus oldStatus = eventInfo.status;
            eventInfo.status = EventStatus.SOLD_OUT;
            emit EventUpdated(eventId, oldStatus, EventStatus.SOLD_OUT);
        }

        emit TicketPurchased(
            eventId,
            typeId,
            msg.sender,
            quantity,
            totalCost,
            false
        );
    }

    /**
     * @dev 购买门票 (使用ETH)
     */
    function purchaseTicketsWithEth(
        uint256 eventId,
        uint256 typeId,
        uint256 quantity,
        uint256[] memory seatNumbers
    ) external payable eventExists(eventId) nonReentrant whenNotPaused {
        require(quantity > 0, "EventManager: invalid quantity");

        EventInfo storage eventInfo = events[eventId];
        require(eventInfo.isApproved, "EventManager: event not approved");
        require(
            typeId < eventInfo.totalTicketTypes,
            "EventManager: invalid ticket type"
        );

        TicketType storage ticketType = eventInfo.ticketTypes[typeId];
        require(
            ticketType.ethPrice > 0,
            "EventManager: ETH payment not supported"
        );

        // 检查销售条件
        _validatePurchaseConditions(eventInfo, ticketType, quantity);

        // 检查库存
        require(
            ticketType.sold + quantity <= ticketType.totalSupply,
            "EventManager: insufficient tickets"
        );

        // 检查ETH支付金额
        uint256 totalCost = ticketType.ethPrice * quantity;
        require(msg.value >= totalCost, "EventManager: insufficient payment");

        // 退还多余的ETH
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        // 分配收入
        _distributeRevenue(eventInfo.organizer, totalCost, true);

        // 铸造门票NFT
        _mintTickets(eventId, typeId, quantity, seatNumbers, ticketType);

        // 更新状态
        ticketType.sold += quantity;
        eventInfo.totalEthRevenue += totalCost;

        emit TicketPurchased(
            eventId,
            typeId,
            msg.sender,
            quantity,
            totalCost,
            true
        );
    }

    /**
     * @dev 验证购买条件
     */
    function _validatePurchaseConditions(
        EventInfo storage eventInfo,
        TicketType storage ticketType,
        uint256 /* quantity */
    ) internal view {
        bool isPresale = block.timestamp >= ticketType.presaleStart &&
            block.timestamp < ticketType.saleStart;
        bool isRegularSale = block.timestamp >= ticketType.saleStart &&
            block.timestamp <= ticketType.saleEnd;

        if (isPresale) {
            require(
                eventInfo.status == EventStatus.PRESALE,
                "EventManager: presale not active"
            );
            require(
                ticketType.presaleWhitelist[msg.sender],
                "EventManager: not in presale whitelist"
            );
        } else if (isRegularSale) {
            require(
                eventInfo.status == EventStatus.ONSALE ||
                    eventInfo.status == EventStatus.PRESALE,
                "EventManager: sale not active"
            );
            require(
                !ticketType.presaleOnly,
                "EventManager: presale only ticket"
            );
        } else {
            revert("EventManager: sale not active");
        }
    }

    /**
     * @dev 分配收入
     */
    function _distributeRevenue(
        address organizer,
        uint256 amount,
        bool isEth
    ) internal {
        uint256 platformFee = (amount * platformFeeRate) / 10000;
        uint256 organizerAmount = amount - platformFee;

        if (isEth) {
            platformEthBalance += platformFee;
            organizerEthBalance[organizer] += organizerAmount;
        } else {
            platformBalance += platformFee;
            organizerBalance[organizer] += organizerAmount;
        }
    }

    /**
     * @dev 铸造门票NFT
     */
    function _mintTickets(
        uint256 eventId,
        uint256 typeId,
        uint256 quantity,
        uint256[] memory seatNumbers,
        TicketType storage ticketType
    ) internal {
        EventInfo storage eventInfo = events[eventId];

        for (uint256 i = 0; i < quantity; i++) {
            uint256 seatNumber = seatNumbers.length > 0 ? seatNumbers[i] : 0;

            // 构建tokenURI (可以更复杂)
            string memory tokenURI = string(
                abi.encodePacked(
                    "https://api.onlineticket.com/metadata/",
                    Strings.toString(eventId),
                    "/",
                    Strings.toString(typeId)
                )
            );

            ticketManager.mintTicket(
                msg.sender,
                eventId,
                seatNumber,
                ticketType.price,
                typeId,
                eventInfo.startTime,
                eventInfo.endTime,
                ticketType.isTransferable,
                ticketType.name,
                tokenURI
            );
        }
    }

    /**
     * @dev 检查是否售罄
     */
    function _checkSoldOut(
        EventInfo storage eventInfo
    ) internal view returns (bool) {
        for (uint256 i = 0; i < eventInfo.totalTicketTypes; i++) {
            TicketType storage ticketType = eventInfo.ticketTypes[i];
            if (ticketType.sold < ticketType.totalSupply) {
                return false;
            }
        }
        return true;
    }

    // ============ 收入管理 ============

    /**
     * @dev 主办方提取收入
     */
    function withdrawRevenue(bool isEth) external nonReentrant {
        if (isEth) {
            uint256 amount = organizerEthBalance[msg.sender];
            require(amount > 0, "EventManager: no ETH balance");

            organizerEthBalance[msg.sender] = 0;
            payable(msg.sender).transfer(amount);

            emit RevenueWithdrawn(msg.sender, amount, true);
        } else {
            uint256 amount = organizerBalance[msg.sender];
            require(amount > 0, "EventManager: no token balance");

            organizerBalance[msg.sender] = 0;
            require(
                platformToken.transfer(msg.sender, amount),
                "EventManager: transfer failed"
            );

            emit RevenueWithdrawn(msg.sender, amount, false);
        }
    }

    /**
     * @dev 平台提取收入 (仅owner)
     */
    function withdrawPlatformRevenue(
        bool isEth,
        uint256 amount
    ) external onlyOwner {
        if (isEth) {
            require(
                amount <= platformEthBalance,
                "EventManager: insufficient balance"
            );
            platformEthBalance -= amount;
            payable(owner()).transfer(amount);
        } else {
            require(
                amount <= platformBalance,
                "EventManager: insufficient balance"
            );
            platformBalance -= amount;
            require(
                platformToken.transfer(owner(), amount),
                "EventManager: transfer failed"
            );
        }
    }

    // ============ 查询功能 ============

    /**
     * @dev 获取活动信息
     */
    function getEventInfo(
        uint256 eventId
    )
        external
        view
        eventExists(eventId)
        returns (
            string memory name,
            string memory description,
            string memory imageURI,
            string memory venue,
            address organizer,
            uint256 startTime,
            uint256 endTime,
            EventStatus status,
            uint256 createdAt,
            uint256 totalTicketTypes,
            uint256 totalRevenue,
            uint256 totalEthRevenue,
            bool requiresApproval,
            bool isApproved
        )
    {
        EventInfo storage eventInfo = events[eventId];
        return (
            eventInfo.name,
            eventInfo.description,
            eventInfo.imageURI,
            eventInfo.venue,
            eventInfo.organizer,
            eventInfo.startTime,
            eventInfo.endTime,
            eventInfo.status,
            eventInfo.createdAt,
            eventInfo.totalTicketTypes,
            eventInfo.totalRevenue,
            eventInfo.totalEthRevenue,
            eventInfo.requiresApproval,
            eventInfo.isApproved
        );
    }

    /**
     * @dev 获取票种信息
     */
    function getTicketTypeInfo(
        uint256 eventId,
        uint256 typeId
    )
        external
        view
        eventExists(eventId)
        returns (
            string memory name,
            uint256 price,
            uint256 ethPrice,
            uint256 totalSupply,
            uint256 sold,
            uint256 presaleStart,
            uint256 saleStart,
            uint256 saleEnd,
            bool isTransferable,
            bool presaleOnly
        )
    {
        require(
            typeId < events[eventId].totalTicketTypes,
            "EventManager: invalid ticket type"
        );

        TicketType storage ticketType = events[eventId].ticketTypes[typeId];
        return (
            ticketType.name,
            ticketType.price,
            ticketType.ethPrice,
            ticketType.totalSupply,
            ticketType.sold,
            ticketType.presaleStart,
            ticketType.saleStart,
            ticketType.saleEnd,
            ticketType.isTransferable,
            ticketType.presaleOnly
        );
    }

    /**
     * @dev 获取主办方的活动列表
     */
    function getOrganizerEvents(
        address organizer
    ) external view returns (uint256[] memory) {
        return organizerEvents[organizer];
    }

    /**
     * @dev 检查用户是否在预售白名单中
     */
    function isInPresaleWhitelist(
        uint256 eventId,
        uint256 typeId,
        address user
    ) external view eventExists(eventId) returns (bool) {
        require(
            typeId < events[eventId].totalTicketTypes,
            "EventManager: invalid ticket type"
        );
        return events[eventId].ticketTypes[typeId].presaleWhitelist[user];
    }

    // ============ 管理功能 ============

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
        require(to != address(0), "EventManager: withdraw to zero address");

        if (token == address(0)) {
            // 提取ETH
            payable(to).transfer(amount);
        } else {
            // 提取ERC20代币
            IERC20(token).transfer(to, amount);
        }
    }

    /**
     * @dev 支持接收ETH
     */
    receive() external payable {}
}
