# 使用示例（部署 / 常用调用）

## **部署**：

用 Foundry / Hardhat / Remix 部署合约，构造函数传入 admin 地址（一般为多签或治理合约地址）。

## **Org 自注册**：

Org 前端生成 DID（例如 did:ethr:0x... 或 did:key:...），调用 registerDID(did, cid)，msg.sender 成为 controller。

## **管理员验证**：

拥有 VERIFIER_ROLE 的后台账户调用 verifyDID(didHash) 将其标记为 verified（可作 KYC 结果）。

## **绑定地址**：

controller 调用 bindAddressToDID(didHash, addr) 将链上钱包地址与 DID 对应（便于合约或后端快速校验）。

## **查询**：

其他合约或后端可通过 getDID(didHash) 或 resolveDIDByAddress(addr) 获取信息。

## **更新**：

controller 可以用 updateCID(didHash, newCid) 更新链下 DID Document 指针；或用 transferController 迁移控制权。

# 安全与扩展建议（注意事项）

## **治理与多签**：

部署时把 admin 设为多签地址（Gnosis Safe），避免单点管理员权限风险。

## **审计**：

在生产前对合约做专业安全审计（尤其是 adminDelete、transferController 等函数）。

## **链下 KYC**：

verifyDID 应由合规 KYC 机构或受信 verifier 来调用；合约只做标记。
地址绑定一致性：addressToDid 为便捷缓存，建议后端在必要时做二次校验（例如 compare did doc controller）。

## **事件驱动**：

后端（Alloy）应监听 DIDRegistered、DIDVerified、DIDRevoked 等事件并更新链下索引/权限系统。

## **隐私**：

DID 文档在 IPFS 上可能包含个人元数据，务必按照法律合规存储与加密；合约只保留 CID 指针与最小必要字段。

# 离线签名与委托调用（高级功能）

## registerWithSig(string did, string cid, uint256 deadline, bytes signature)：

允许控制者离线签名注册 DID，任何人（relayer）可提交该签名并在链上完成注册（relayer 支付 gas）。

## bindWithSig(bytes32 didHash, address addr, uint256 deadline, bytes signature)：

允许 controller 离线签名，将一个链上地址与 DID 绑定（委托绑定），relayer 代为上链。

## 设计要点包括：

使用 OpenZeppelin 的 EIP712 与 ECDSA 进行签名/恢复与规范化（避免重放攻击）。
每个签名者维护 nonces，签名包含当前 nonce（并由链端消费），作为防重放保护。
签名包含 deadline，可设置过期时间。
恢复出的 signer 会作为 controller（在 registerWithSig 中），或必须等于 DID 的 controller（在 bindWithSig 中）。
保留原有的基于角色（VERIFIER_ROLE、DEFAULT_ADMIN_ROLE）的管理接口与事件。
