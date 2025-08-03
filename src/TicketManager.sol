// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TicketManager
 * @dev 基于ERC721标准的门票NFT合约
 * @notice 管理门票的发行、转移、验证等核心功能
 */
contract TicketManager is
    ERC721,
    ERC721URIStorage,
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    // ============ 状态变量 ============

    uint256 private _nextTokenId;

    // 门票状态枚举
    enum TicketStatus {
        VALID, // 有效
        USED, // 已使用
        CANCELLED, // 已取消
        EXPIRED // 已过期
    }

    // 门票元数据结构
    struct TicketMetadata {
        uint256 eventId; // 活动ID
        uint256 seatNumber; // 座位号 (0表示无座位)
        uint256 originalPrice; // 原价
        uint256 category; // 票种类别
        uint256 validFrom; // 有效开始时间
        uint256 validUntil; // 有效结束时间
        TicketStatus status; // 门票状态
        address originalBuyer; // 原始购买者
        uint256 purchaseTime; // 购买时间
        bool isTransferable; // 是否可转让
        string seatSection; // 座位区域 (如"VIP区", "普通区")
        bytes32 verificationHash; // 验证哈希
    }

    // ============ 映射 ============

    // 门票ID -> 门票元数据
    mapping(uint256 => TicketMetadata) public tickets;

    // 活动ID -> 门票ID列表
    mapping(uint256 => uint256[]) public eventTickets;

    // 活动ID -> 座位号 -> 门票ID (用于座位唯一性检查)
    mapping(uint256 => mapping(uint256 => uint256)) public seatToTicket;

    // 授权的铸造者 (如Marketplace合约)
    mapping(address => bool) public authorizedMinters;

    // 授权的验证者 (如验票系统)
    mapping(address => bool) public authorizedVerifiers;

    // 用户购买限制 (活动ID -> 用户地址 -> 购买数量)
    mapping(uint256 => mapping(address => uint256)) public userPurchaseCount;

    // 活动购买限制
    mapping(uint256 => uint256) public eventPurchaseLimit;

    // ============ 事件 ============

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
        TicketStatus oldStatus,
        TicketStatus newStatus
    );

    event MinterAuthorized(address indexed minter, bool authorized);
    event VerifierAuthorized(address indexed verifier, bool authorized);

    // ============ 构造函数 ============

    constructor(
        address initialOwner
    ) ERC721("OnlineTicket NFT", "OTN") Ownable(initialOwner) {
        // 从tokenId 1开始
        _nextTokenId = 1;
    }

    // ============ 权限管理 ============

    modifier onlyAuthorizedMinter() {
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(),
            "TicketManager: unauthorized minter"
        );
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(
            authorizedVerifiers[msg.sender] || msg.sender == owner(),
            "TicketManager: unauthorized verifier"
        );
        _;
    }

    modifier ticketExists(uint256 tokenId) {
        require(
            _ownerOf(tokenId) != address(0),
            "TicketManager: ticket does not exist"
        );
        _;
    }

    /**
     * @dev 授权铸造者
     */
    function setMinterAuthorization(
        address minter,
        bool authorized
    ) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }

    /**
     * @dev 授权验证者
     */
    function setVerifierAuthorization(
        address verifier,
        bool authorized
    ) external onlyOwner {
        authorizedVerifiers[verifier] = authorized;
        emit VerifierAuthorized(verifier, authorized);
    }

    // ============ 门票铸造 ============

    /**
     * @dev 铸造门票
     */
    function mintTicket(
        address to,
        uint256 eventId,
        uint256 seatNumber,
        uint256 originalPrice,
        uint256 category,
        uint256 validFrom,
        uint256 validUntil,
        bool isTransferable,
        string memory seatSection,
        string memory uri
    ) external onlyAuthorizedMinter nonReentrant returns (uint256) {
        require(to != address(0), "TicketManager: mint to zero address");
        require(validFrom < validUntil, "TicketManager: invalid time range");
        require(validUntil > block.timestamp, "TicketManager: already expired");

        // 检查购买限制
        uint256 purchaseLimit = eventPurchaseLimit[eventId];
        if (purchaseLimit > 0) {
            require(
                userPurchaseCount[eventId][to] < purchaseLimit,
                "TicketManager: purchase limit exceeded"
            );
        }

        // 检查座位唯一性 (如果有座位号)
        if (seatNumber > 0) {
            require(
                seatToTicket[eventId][seatNumber] == 0,
                "TicketManager: seat already taken"
            );
        }

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        // 生成验证哈希
        bytes32 verificationHash = keccak256(
            abi.encodePacked(tokenId, eventId, to, block.timestamp)
        );

        // 创建门票元数据
        tickets[tokenId] = TicketMetadata({
            eventId: eventId,
            seatNumber: seatNumber,
            originalPrice: originalPrice,
            category: category,
            validFrom: validFrom,
            validUntil: validUntil,
            status: TicketStatus.VALID,
            originalBuyer: to,
            purchaseTime: block.timestamp,
            isTransferable: isTransferable,
            seatSection: seatSection,
            verificationHash: verificationHash
        });

        // 更新映射
        eventTickets[eventId].push(tokenId);
        if (seatNumber > 0) {
            seatToTicket[eventId][seatNumber] = tokenId;
        }
        userPurchaseCount[eventId][to]++;

        // 铸造NFT
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TicketMinted(tokenId, eventId, to, seatNumber, originalPrice);

        return tokenId;
    }

    /**
     * @dev 批量铸造门票
     */
    function batchMintTickets(
        address[] memory recipients,
        uint256 eventId,
        uint256[] memory seatNumbers,
        uint256 originalPrice,
        uint256 category,
        uint256 validFrom,
        uint256 validUntil,
        bool isTransferable,
        string memory seatSection,
        string[] memory tokenURIs
    ) external onlyAuthorizedMinter nonReentrant returns (uint256[] memory) {
        require(recipients.length > 0, "TicketManager: empty recipients");
        require(
            recipients.length == seatNumbers.length &&
                recipients.length == tokenURIs.length,
            "TicketManager: array length mismatch"
        );
        require(recipients.length <= 100, "TicketManager: batch too large");

        uint256[] memory tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 seatNumber = seatNumbers[i];
            string memory uri = tokenURIs[i];

            require(to != address(0), "TicketManager: mint to zero address");
            require(
                validFrom < validUntil,
                "TicketManager: invalid time range"
            );
            require(
                validUntil > block.timestamp,
                "TicketManager: already expired"
            );

            // 检查购买限制
            uint256 purchaseLimit = eventPurchaseLimit[eventId];
            if (purchaseLimit > 0) {
                require(
                    userPurchaseCount[eventId][to] < purchaseLimit,
                    "TicketManager: purchase limit exceeded"
                );
            }

            // 检查座位唯一性 (如果有座位号)
            if (seatNumber > 0) {
                require(
                    seatToTicket[eventId][seatNumber] == 0,
                    "TicketManager: seat already taken"
                );
            }

            uint256 tokenId = _nextTokenId;
            _nextTokenId++;

            // 生成验证哈希
            bytes32 verificationHash = keccak256(
                abi.encodePacked(tokenId, eventId, to, block.timestamp)
            );

            // 创建门票元数据
            tickets[tokenId] = TicketMetadata({
                eventId: eventId,
                seatNumber: seatNumber,
                originalPrice: originalPrice,
                category: category,
                validFrom: validFrom,
                validUntil: validUntil,
                status: TicketStatus.VALID,
                originalBuyer: to,
                purchaseTime: block.timestamp,
                isTransferable: isTransferable,
                seatSection: seatSection,
                verificationHash: verificationHash
            });

            // 更新映射
            eventTickets[eventId].push(tokenId);
            if (seatNumber > 0) {
                seatToTicket[eventId][seatNumber] = tokenId;
            }
            userPurchaseCount[eventId][to]++;

            // 铸造NFT
            _mint(to, tokenId);
            _setTokenURI(tokenId, uri);

            tokenIds[i] = tokenId;
            emit TicketMinted(tokenId, eventId, to, seatNumber, originalPrice);
        }

        return tokenIds;
    }

    // ============ 门票验证与使用 ============

    /**
     * @dev 验证并使用门票
     */
    function useTicket(
        uint256 tokenId
    ) external onlyAuthorizedVerifier ticketExists(tokenId) nonReentrant {
        TicketMetadata storage ticket = tickets[tokenId];

        require(
            ticket.status == TicketStatus.VALID,
            "TicketManager: ticket not valid"
        );
        require(
            block.timestamp >= ticket.validFrom &&
                block.timestamp <= ticket.validUntil,
            "TicketManager: ticket not in valid time range"
        );

        // 更新状态
        TicketStatus oldStatus = ticket.status;
        ticket.status = TicketStatus.USED;

        emit TicketUsed(tokenId, ticket.eventId, msg.sender);
        emit TicketStatusChanged(tokenId, oldStatus, TicketStatus.USED);
    }

    /**
     * @dev 验证门票有效性（只读）
     */
    function isTicketValid(
        uint256 tokenId
    ) external view ticketExists(tokenId) returns (bool) {
        TicketMetadata memory ticket = tickets[tokenId];

        return (ticket.status == TicketStatus.VALID &&
            block.timestamp >= ticket.validFrom &&
            block.timestamp <= ticket.validUntil);
    }

    /**
     * @dev 验证门票哈希
     */
    function verifyTicketHash(
        uint256 tokenId,
        bytes32 providedHash
    ) external view ticketExists(tokenId) returns (bool) {
        return tickets[tokenId].verificationHash == providedHash;
    }

    // ============ 门票管理 ============

    /**
     * @dev 取消门票
     */
    function cancelTicket(
        uint256 tokenId,
        string memory reason
    ) external onlyOwner ticketExists(tokenId) {
        TicketMetadata storage ticket = tickets[tokenId];
        require(
            ticket.status == TicketStatus.VALID,
            "TicketManager: ticket not valid"
        );

        TicketStatus oldStatus = ticket.status;
        ticket.status = TicketStatus.CANCELLED;

        emit TicketCancelled(tokenId, ticket.eventId, reason);
        emit TicketStatusChanged(tokenId, oldStatus, TicketStatus.CANCELLED);
    }

    /**
     * @dev 设置门票转让权限
     */
    function setTicketTransferable(
        uint256 tokenId,
        bool transferable
    ) external onlyOwner ticketExists(tokenId) {
        tickets[tokenId].isTransferable = transferable;
    }

    /**
     * @dev 设置活动购买限制
     */
    function setEventPurchaseLimit(
        uint256 eventId,
        uint256 limit
    ) external onlyOwner {
        eventPurchaseLimit[eventId] = limit;
    }

    /**
     * @dev 批量过期门票
     */
    function expireTickets(uint256[] memory tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (
                _ownerOf(tokenId) != address(0) &&
                tickets[tokenId].status == TicketStatus.VALID
            ) {
                TicketStatus oldStatus = tickets[tokenId].status;
                tickets[tokenId].status = TicketStatus.EXPIRED;
                emit TicketStatusChanged(
                    tokenId,
                    oldStatus,
                    TicketStatus.EXPIRED
                );
            }
        }
    }

    // ============ 转移控制 ============

    /**
     * @dev 重写更新函数，在v5中替代_beforeTokenTransfer
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
        returns (address)
    {
        address from = _ownerOf(tokenId);

        // 铸造时跳过检查 (from == address(0))
        if (from != address(0)) {
            // 检查是否可转让
            require(
                tickets[tokenId].isTransferable,
                "TicketManager: ticket not transferable"
            );

            // 检查门票状态
            require(
                tickets[tokenId].status == TicketStatus.VALID,
                "TicketManager: invalid ticket status"
            );
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev 重写_increaseBalance来解决多重继承冲突
     */
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    // ============ 查询功能 ============

    /**
     * @dev 获取门票完整信息
     */
    function getTicketInfo(
        uint256 tokenId
    ) external view ticketExists(tokenId) returns (TicketMetadata memory) {
        return tickets[tokenId];
    }

    /**
     * @dev 获取活动的所有门票
     */
    function getEventTickets(
        uint256 eventId
    ) external view returns (uint256[] memory) {
        return eventTickets[eventId];
    }

    /**
     * @dev 获取用户在特定活动的门票
     */
    function getUserEventTickets(
        address user,
        uint256 eventId
    ) external view returns (uint256[] memory) {
        uint256[] memory allEventTickets = eventTickets[eventId];
        uint256[] memory userTickets = new uint256[](balanceOf(user));
        uint256 count = 0;

        for (uint256 i = 0; i < allEventTickets.length; i++) {
            uint256 tokenId = allEventTickets[i];
            if (ownerOf(tokenId) == user) {
                userTickets[count] = tokenId;
                count++;
            }
        }

        // 调整数组大小
        assembly {
            mstore(userTickets, count)
        }

        return userTickets;
    }

    /**
     * @dev 获取用户所有门票
     */
    function getUserTickets(
        address user
    ) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory userTokens = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            userTokens[i] = tokenOfOwnerByIndex(user, i);
        }

        return userTokens;
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
        require(to != address(0), "TicketManager: withdraw to zero address");

        if (token == address(0)) {
            // 提取ETH
            payable(to).transfer(amount);
        } else {
            // 提取ERC20代币
            IERC20(token).transfer(to, amount);
        }
    }

    // ============ 重写必要的函数 ============

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
