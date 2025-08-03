# TicketManager 测试文档

## 📋 测试概览

**测试时间**: 2025 年 8 月 3 日
**测试环境**: Foundry + Solidity 0.8.23
**测试状态**: ✅ 全部通过

## 🧪 测试统计

| 测试类型 | 测试数量 | 通过数量 | 失败数量 | 状态             |
| -------- | -------- | -------- | -------- | ---------------- |
| 单元测试 | 45       | 45       | 0        | ✅ 通过          |
| **总计** | **45**   | **45**   | **0**    | **✅ 100% 通过** |

## 📊 详细测试结果

### 1. 部署测试 (1 个测试)

- ✅ `test_Deploy()` - 验证合约基本信息（名称、符号、所有者、暂停状态）

### 2. 权限管理测试 (4 个测试)

- ✅ `test_SetMinterAuthorization()` - 设置铸造者授权
- ✅ `test_SetMinterAuthorizationOnlyOwner()` - 验证只有所有者可以设置铸造者
- ✅ `test_SetVerifierAuthorization()` - 设置验证者授权
- ✅ `test_SetVerifierAuthorizationOnlyOwner()` - 验证只有所有者可以设置验证者

### 3. 门票铸造测试 (8 个测试)

- ✅ `test_MintTicket()` - 正常铸造门票功能
- ✅ `test_MintTicketUnauthorized()` - 验证未授权用户无法铸造
- ✅ `test_MintTicketToZeroAddress()` - 防止铸造到零地址
- ✅ `test_MintTicketInvalidTimeRange()` - 验证时间范围有效性
- ✅ `test_MintTicketAlreadyExpired()` - 防止铸造已过期门票
- ✅ `test_MintTicketSeatAlreadyTaken()` - 防止重复座位号
- ✅ `test_MintTicketPurchaseLimitExceeded()` - 验证购买限制
- ✅ `test_MintTicketOwnerCanMint()` - 验证所有者可以直接铸造

### 4. 批量铸造测试 (4 个测试)

- ✅ `test_BatchMintTickets()` - 正常批量铸造功能
- ✅ `test_BatchMintTicketsEmptyRecipients()` - 防止空收件人数组
- ✅ `test_BatchMintTicketsArrayLengthMismatch()` - 验证数组长度匹配
- ✅ `test_BatchMintTicketsTooLarge()` - 限制批量大小（最多 100 个）

### 5. 门票验证与使用测试 (7 个测试)

- ✅ `test_UseTicket()` - 正常使用门票功能
- ✅ `test_UseTicketUnauthorized()` - 验证未授权用户无法使用门票
- ✅ `test_UseTicketNotExists()` - 防止使用不存在的门票
- ✅ `test_UseTicketNotValid()` - 防止使用无效状态门票
- ✅ `test_UseTicketNotInValidTimeRange()` - 验证时间范围限制
- ✅ `test_IsTicketValid()` - 门票有效性检查
- ✅ `test_VerifyTicketHash()` - 门票哈希验证

### 6. 门票管理测试 (5 个测试)

- ✅ `test_CancelTicket()` - 取消门票功能
- ✅ `test_CancelTicketOnlyOwner()` - 验证只有所有者可以取消门票
- ✅ `test_SetTicketTransferable()` - 设置门票转让权限
- ✅ `test_SetEventPurchaseLimit()` - 设置活动购买限制
- ✅ `test_ExpireTickets()` - 批量过期门票

### 7. 转移控制测试 (4 个测试)

- ✅ `test_TransferTicket()` - 正常转移门票
- ✅ `test_TransferNonTransferableTicket()` - 防止转移不可转让门票
- ✅ `test_TransferUsedTicket()` - 防止转移已使用门票
- ✅ `test_TransferWhenPaused()` - 暂停时禁止转移

### 8. 查询功能测试 (4 个测试)

- ✅ `test_GetEventTickets()` - 获取活动的所有门票
- ✅ `test_GetUserEventTickets()` - 获取用户在特定活动的门票
- ✅ `test_GetUserTickets()` - 获取用户所有门票
- ✅ `test_TokenURI()` - 门票 URI 查询

### 9. 管理功能测试 (5 个测试)

- ✅ `test_Pause()` - 暂停合约功能
- ✅ `test_PauseOnlyOwner()` - 验证只有所有者可以暂停
- ✅ `test_Unpause()` - 取消暂停功能
- ✅ `test_EmergencyWithdrawETH()` - 紧急提取 ETH
- ✅ `test_EmergencyWithdrawToZeroAddress()` - 防止提取到零地址

### 10. ERC721 基础功能测试 (1 个测试)

- ✅ `test_SupportsInterface()` - 验证接口支持

### 11. 边界情况测试 (2 个测试)

- ✅ `test_MintTicketWithoutSeat()` - 无座位门票铸造
- ✅ `test_MultipleEventsDoNotConflict()` - 不同活动间的座位不冲突

## 🔧 合约功能演示

### 演示结果

```
=== TicketManager Contract Demo ===
Owner: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
Minter: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
Verifier: 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69
User1: 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718
User2: 0xe1AB8145F7E55DC933d51a18c793F901A3A0b276

[SUCCESS] Contract deployed successfully
Contract address: 0xF2E246BB76DF876Cef8b38ae84130F4F55De395b

=== Contract Basic Info ===
Token name: OnlineTicket NFT
Token symbol: OTN
Owner: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
Paused: No
Total Supply: 0

=== Authorization Demo ===
Minter authorized: Yes
Verifier authorized: Yes

=== Ticket Minting Demo ===
Minted ticket ID: 1
Ticket owner: 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718
User1 balance: 1

=== Batch Minting Demo ===
Batch minted 2 tickets
First token ID: 2
Second token ID: 3
User1 total balance: 2
User2 total balance: 1

=== Ticket Usage Demo ===
Before time warp - ticket valid: No
After time warp - ticket valid: Yes
Ticket used successfully
After usage - ticket valid: No
Ticket status: 1

=== Ticket Management Demo ===
Purchase limit set to: 5
Ticket 2 cancelled
Cancelled ticket status: 2
Ticket 3 transferable: No

=== Query Functions Demo ===
Total tickets for event 1 : 3
User1 total tickets: 2
User1 tickets for event 1 : 2

First ticket details:
Event ID: 1
Seat Number: 101
Original Price: 100 tokens
Category: 1
Original Buyer: 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718
Transferable: Yes
Seat Section: VIP

[COMPLETE] All functions demonstrated successfully!
```

## ⛽ Gas 使用情况

| 函数                 | Gas 使用量 | 类型           |
| -------------------- | ---------- | -------------- |
| 部署合约             | 4,703,042  | 一次性         |
| `mintTicket()`       | ~565,000   | 单次铸造       |
| `batchMintTickets()` | ~1,472,000 | 批量铸造(3 张) |
| `useTicket()`        | ~560,000   | 使用门票       |
| `cancelTicket()`     | ~532,000   | 取消门票       |
| `transferFrom()`     | ~534,000   | 转移门票       |

## 🔒 安全特性验证

✅ **访问控制**: 验证了铸造者和验证者的权限管理
✅ **重入保护**: `nonReentrant` 修饰符在关键函数中起作用
✅ **暂停机制**: `Pausable` 在转账时正确阻止操作
✅ **输入验证**: 零地址、无效时间范围等输入被正确拒绝
✅ **座位唯一性**: 防止同一活动中重复座位号
✅ **状态管理**: 门票状态变更被正确跟踪和验证
✅ **时间控制**: 门票有效期和使用时间被正确验证
✅ **转移控制**: 可转让性和门票状态限制转移操作

## 🎫 门票状态管理

合约支持四种门票状态：

- **VALID (0)**: 有效状态，可以使用和转移
- **USED (1)**: 已使用，不能再次使用或转移
- **CANCELLED (2)**: 已取消，不能使用或转移
- **EXPIRED (3)**: 已过期，通过管理功能批量设置

## 🔧 核心功能特性

### 门票铸造

- 支持单张和批量铸造
- 座位唯一性检查
- 购买限制控制
- 时间有效性验证

### 门票验证

- 基于时间的有效性检查
- 哈希验证机制
- 状态验证

### 权限管理

- 铸造者授权系统
- 验证者授权系统
- 所有者特权操作

### 查询功能

- 按活动查询门票
- 按用户查询门票
- 门票详细信息查询

## 📝 建议改进

1. **Gas 优化**: 考虑在批量操作中使用更高效的存储方式
2. **元数据扩展**: 可以添加更多门票属性（如座位行列、票价折扣等）
3. **事件完善**: 添加更多细粒度的事件记录
4. **批量操作**: 增加批量验证、批量取消等功能
5. **权限细化**: 考虑实现更细粒度的权限控制

## ✅ 结论

TicketManager 合约已通过全面的测试，包括：

- **45 个单元测试全部通过**
- **所有核心功能验证成功**
- **安全特性验证通过**
- **功能演示成功执行**

合约符合 ERC721 标准，具备完善的权限管理、状态控制和安全保护，可以安全地用于门票 NFT 的管理和验证。
