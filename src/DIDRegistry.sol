// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DIDRegistry is AccessControl {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    struct DIDDoc {
        address controller; // 控制者（可更新 metadata、转移控制权）
        string did; // 原始 did 字符串（例如 did:ethr:0x...）
        string cid; // 指向链下 DID Document 或元数据的 IPFS CID/URI
        bool verified; // 是否已被 verifier 验证
        bool revoked; // 是否已撤销
        uint256 createdAt; // 时间戳
        uint256 updatedAt; // 时间戳
    }
    /// @dev didHash => DIDDoc
    mapping(bytes32 => DIDDoc) private docs;

    /// @dev address => didHash  (用于快速查找已绑定到某地址的 DID)
    mapping(address => bytes32) public addressToDid;

    event DIDRegistered(
        bytes32 indexed didHash,
        string did,
        address indexed controller,
        string cid
    );
    event DIDUpdated(
        bytes32 indexed didHash,
        string oldCid,
        string newCid,
        uint256 updatedAt
    );
    event DIDVerified(
        bytes32 indexed didHash,
        address indexed verifier,
        uint256 verifiedAt
    );
    event DIDRevoked(
        bytes32 indexed didHash,
        address indexed by,
        uint256 revokedAt
    );
    event DIDControllerTransferred(
        bytes32 indexed didHash,
        address indexed oldController,
        address indexed newController,
        uint256 at
    );
    event DIDBoundToAddress(bytes32 indexed didHash, address indexed addr);
    event DIDUnboundFromAddress(bytes32 indexed didHash, address indexed addr);

    modifier onlyController(bytes32 didHash) {
        require(docs[didHash].controller != address(0), "DID: not registered");
        require(docs[didHash].controller == msg.sender, "DID: not controller");
        _;
    }

    constructor(address admin) {
        require(admin != address(0), "admin zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        // admin 默认也是 verifier
        _grantRole(VERIFIER_ROLE, admin);
    }

    /// @notice Register a DID with msg.sender as controller
    /// @param did The DID string, e.g., "did:ethr:0xabc..."
    /// @param cid A pointer to DID Document or metadata (IPFS CID/URI)
    /// @return didHash keccak256(did) used as index
    function registerDID(
        string calldata did,
        string calldata cid
    ) external returns (bytes32 didHash) {
        require(bytes(did).length > 0, "DID: empty");
        bytes32 id = keccak256(bytes(did));
        DIDDoc storage doc = docs[id];
        require(doc.controller == address(0), "DID: already exists");

        doc.controller = msg.sender;
        doc.did = did;
        doc.cid = cid;
        doc.verified = false;
        doc.revoked = false;
        doc.createdAt = block.timestamp;
        doc.updatedAt = block.timestamp;

        emit DIDRegistered(id, did, msg.sender, cid);
        return id;
    }
    /// @notice Register on-behalf: admin or other may register with a specified controller
    /// @dev only admin can call this to bootstrap orgs
    function registerDIDFor(
        string calldata did,
        string calldata cid,
        address controller
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes32 didHash) {
        require(bytes(did).length > 0, "DID: empty");
        require(controller != address(0), "controller zero");
        bytes32 id = keccak256(bytes(did));
        DIDDoc storage doc = docs[id];
        require(doc.controller == address(0), "DID: already exists");

        doc.controller = controller;
        doc.did = did;
        doc.cid = cid;
        doc.verified = false;
        doc.revoked = false;
        doc.createdAt = block.timestamp;
        doc.updatedAt = block.timestamp;

        emit DIDRegistered(id, did, controller, cid);
        return id;
    }

    /// @notice Update metadata CID for a DID — only controller can update
    function updateCID(
        bytes32 didHash,
        string calldata newCid
    ) external onlyController(didHash) {
        DIDDoc storage doc = docs[didHash];
        string memory oldCid = doc.cid;
        doc.cid = newCid;
        doc.updatedAt = block.timestamp;
        emit DIDUpdated(didHash, oldCid, newCid, block.timestamp);
    }

    /// @notice Verify a DID (KYC/verification) — only verifier role
    function verifyDID(bytes32 didHash) external onlyRole(VERIFIER_ROLE) {
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        require(!doc.revoked, "DID: revoked");
        doc.verified = true;
        doc.updatedAt = block.timestamp;
        emit DIDVerified(didHash, msg.sender, block.timestamp);
    }

    /// @notice Revoke a DID (controller or admin)
    function revokeDID(bytes32 didHash) external {
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        require(
            msg.sender == doc.controller ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "DID: not authorized"
        );
        doc.revoked = true;
        doc.updatedAt = block.timestamp;
        emit DIDRevoked(didHash, msg.sender, block.timestamp);
    }

    /// @notice Transfer controller role to new address — only controller
    function transferController(
        bytes32 didHash,
        address newController
    ) external onlyController(didHash) {
        require(newController != address(0), "DID: newController zero");
        DIDDoc storage doc = docs[didHash];
        address old = doc.controller;
        doc.controller = newController;
        doc.updatedAt = block.timestamp;
        emit DIDControllerTransferred(
            didHash,
            old,
            newController,
            block.timestamp
        );
    }

    /// @notice Bind a DID to an on-chain address (one-to-one mapping). Caller must be controller or admin.
    /// @dev This is an on-chain mapping for quick lookup; it does not replace off-chain DID docs.
    function bindAddressToDID(bytes32 didHash, address addr) external {
        require(addr != address(0), "DID: addr zero");
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        require(
            msg.sender == doc.controller ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "DID: not authorized"
        );
        addressToDid[addr] = didHash;
        emit DIDBoundToAddress(didHash, addr);
    }

    /// @notice Unbind DID from an address — controller or admin
    function unbindAddress(bytes32 didHash, address addr) external {
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        require(
            msg.sender == doc.controller ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "DID: not authorized"
        );
        bytes32 mapped = addressToDid[addr];
        require(mapped == didHash, "DID: mismatch bind");
        delete addressToDid[addr];
        emit DIDUnboundFromAddress(didHash, addr);
    }

    /// @notice Lookup DIDDoc by didHash
    function getDID(
        bytes32 didHash
    )
        external
        view
        returns (
            address controller,
            string memory did,
            string memory cid,
            bool verified,
            bool revoked,
            uint256 createdAt,
            uint256 updatedAt
        )
    {
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        return (
            doc.controller,
            doc.did,
            doc.cid,
            doc.verified,
            doc.revoked,
            doc.createdAt,
            doc.updatedAt
        );
    }

    /// @notice Convenience: resolve DID by address
    function resolveDIDByAddress(
        address addr
    ) external view returns (bytes32 didHash) {
        return addressToDid[addr];
    }

    /// @notice Check if DID is verified
    function isVerified(bytes32 didHash) external view returns (bool) {
        DIDDoc storage doc = docs[didHash];
        if (doc.controller == address(0)) return false;
        return doc.verified && !doc.revoked;
    }

    /// @notice Admin helper: set or revoke verifier role
    function setVerifier(
        address verifier,
        bool enabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (enabled) {
            grantRole(VERIFIER_ROLE, verifier);
        } else {
            revokeRole(VERIFIER_ROLE, verifier);
        }
    }

    /// @notice Admin helper: emergency remove DID (completely delete)
    function adminDeleteDID(
        bytes32 didHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        DIDDoc storage doc = docs[didHash];
        require(doc.controller != address(0), "DID: not exist");
        delete docs[didHash];
        // Note: we do not attempt to cleanup addressToDid mappings here (they may still point to didHash)
        // Consumers should handle stale mappings if needed.
    }
}
