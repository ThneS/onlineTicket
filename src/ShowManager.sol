// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "./DIDRegistry.sol";

contract ShowManager {
    enum ShowStatus {
        Upcoming,
        Active,
        Ended,
        Cancelled
    } // 演出状态枚举
    DIDRegistry public didRegistry; // DID 注册合约实例
    struct Show {
        uint256 id; // 演出 ID
        uint256 startTime; // 演出开始时间（时间戳）
        uint256 endTime; // 售票结束时间（时间戳）
        uint256 totalTickets; // 总票数
        uint256 ticketsSold; // 已售票数
        uint256 ticketPrice; // 票价（以 wei 为单位）
        address organizer; // 组织者地址
        string location; // 演出地点
        string name; // 演出名称
        string description; // 演出描述
        string metadataURI; // IPFS CID
        ShowStatus status; // 演出状态
    }
    mapping(uint256 => Show) shows; // 记录演出信息
    uint256 private _showCounter; // 演出计数器
    address public admin; // 管理员地址
    address public organizer; // 组织者地址
    address public feeRecipient; // 手续费接收地址

    uint256 public nextShowId; // 下一个演出 ID
    uint256 public platformFee; // 平台手续费（以百分比表示，例如 5 表示 5%）
    uint256 public constant MAX_PLATFORM_FEE = 10; // 最大平台手续费（10%）
    uint256 public constant MIN_TICKET_PRICE = 0.01 ether; // 最低票价（0.01 ETH）
    uint256 public constant MAX_TICKETS_PER_SHOW = 10000; // 每场演出的最大票数

    event ShowCreated(
        uint256 indexed showId,
        address indexed organizer,
        string name,
        uint256 startTime,
        uint256 endTime,
        string venue
    );

    event ShowUpdated(uint256 indexed showId, string name, string metadataURI);
    event ShowCancelled(uint256 indexed showId);
    event ShowActivated(uint256 indexed showId);
    event ShowEnded(uint256 indexed showId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    modifier onlyOrganizer(uint256 showId) {
        require(
            msg.sender == shows[showId].organizer,
            "Only organizer can perform this action"
        );
        _;
    }
    modifier adminOrOrganizer(uint256 showId) {
        require(
            msg.sender == admin || msg.sender == shows[showId].organizer,
            "Only admin or organizer can perform this action"
        );
        _;
    }
    modifier showExists(uint256 showId) {
        require(shows[showId].id != 0, "Show does not exist");
        _;
    }

    modifier validTicketPurchase(uint256 showId, uint256 quantity) {
        Show storage show = shows[showId];
        require(
            block.timestamp < show.endTime,
            "Ticket sales have ended for this show"
        );
        require(
            show.ticketsSold + quantity <= show.totalTickets,
            "Not enough tickets available"
        );
        require(
            msg.value >= show.ticketPrice * quantity,
            "Insufficient payment"
        );
        _;
    }

    constructor(
        address _feeRecipient,
        uint256 _platformFee,
        address _didRegistry
    ) {
        require(
            _platformFee <= MAX_PLATFORM_FEE,
            "Platform fee exceeds maximum"
        );
        admin = msg.sender;
        didRegistry = DIDRegistry(_didRegistry);
        feeRecipient = _feeRecipient;
        platformFee = _platformFee;
        nextShowId = 1; // 从 1 开始分配演出 ID
    }

    // 创建活动
    function createShow(
        string memory name,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        string memory location,
        uint256 totalTickets,
        uint256 ticketPrice,
        string memory ipfsCID
    ) external {
        bytes32 didHash = didRegistry.resolveDIDByAddress(msg.sender);
        require(didHash != bytes32(0), "Organizer must have a valid DID");
        require(bytes(name).length > 0, "Show name is required");
        require(startTime < endTime, "Invalid show time range");
        require(
            totalTickets > 0 && totalTickets <= MAX_TICKETS_PER_SHOW,
            "Invalid total tickets"
        );
        require(ticketPrice >= MIN_TICKET_PRICE, "Ticket price too low");

        shows[nextShowId] = Show(
            nextShowId,
            startTime,
            endTime,
            totalTickets,
            0,
            ticketPrice,
            msg.sender,
            location,
            name,
            description,
            ipfsCID,
            ShowStatus.Upcoming
        );

        emit ShowCreated(
            nextShowId,
            msg.sender,
            name,
            startTime,
            endTime,
            location
        );
        nextShowId++;
    }

    function updateShow(
        uint256 showId,
        string memory name,
        string memory metadataURI
    ) external showExists(showId) adminOrOrganizer(showId) {
        Show storage s = shows[showId];
        require(
            s.status == ShowStatus.Upcoming,
            "Cannot update active/cancelled/ended"
        );

        s.name = name;
        s.metadataURI = metadataURI;

        emit ShowUpdated(showId, name, metadataURI);
    }

    function cancelShow(
        uint256 showId
    ) external showExists(showId) adminOrOrganizer(showId) {
        Show storage s = shows[showId];
        require(s.status == ShowStatus.Upcoming, "Only upcoming can cancel");

        s.status = ShowStatus.Cancelled;
        emit ShowCancelled(showId);
    }

    function activateShow(
        uint256 showId
    ) external showExists(showId) adminOrOrganizer(showId) {
        Show storage s = shows[showId];
        require(s.status == ShowStatus.Upcoming, "Only upcoming can activate");
        require(block.timestamp >= s.startTime, "Too early to activate");

        s.status = ShowStatus.Active;
        emit ShowActivated(showId);
    }

    function endShow(
        uint256 showId
    ) external showExists(showId) adminOrOrganizer(showId) {
        Show storage s = shows[showId];
        require(s.status == ShowStatus.Active, "Only active can end");
        require(block.timestamp >= s.endTime, "Too early to end");

        s.status = ShowStatus.Ended;
        emit ShowEnded(showId);
    }

    function getShow(
        uint256 showId
    ) external view showExists(showId) returns (Show memory) {
        return shows[showId];
    }

    function getShows() external view returns (Show[] memory) {
        Show[] memory allShows = new Show[](nextShowId - 1);
        for (uint256 i = 1; i < nextShowId; i++) {
            allShows[i - 1] = shows[i];
        }
        return allShows;
    }
}
