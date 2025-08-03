# 测试文档

本目录包含 OnlineTicket 项目的所有测试文件和相关文档。

## 📁 文件结构

```
test/
├── README.md                           # 本文档
├── PlatformToken.t.sol                # PlatformToken 合约测试
├── TicketManager.t.sol                # TicketManager 合约测试
└── TicketManager_TEST_REPORT.md       # TicketManager 测试报告
```

## 🧪 测试概览

### PlatformToken 测试

- **文件**: `PlatformToken.t.sol`
- **测试数量**: 37 个（包含 2 个模糊测试）
- **状态**: ✅ 全部通过
- **覆盖范围**: ERC20 代币的所有核心功能

### TicketManager 测试

- **文件**: `TicketManager.t.sol`
- **测试数量**: 45 个
- **状态**: ✅ 全部通过
- **覆盖范围**: ERC721 门票 NFT 的所有核心功能

## 🚀 运行测试

### 运行所有测试

```bash
forge test
```

### 运行特定合约的测试

```bash
# PlatformToken 测试
forge test --match-contract PlatformTokenTest

# TicketManager 测试
forge test --match-contract TicketManagerTest
```

### 运行特定测试文件

```bash
# PlatformToken 测试
forge test test/PlatformToken.t.sol -v

# TicketManager 测试
forge test test/TicketManager.t.sol -v
```

### 运行特定测试函数

```bash
# 运行铸造相关测试
forge test --match-test test_Mint

# 运行批量操作测试
forge test --match-test test_Batch
```

### 查看详细输出

```bash
# 显示详细日志
forge test -v

# 显示非常详细的日志
forge test -vv

# 显示失败测试的堆栈跟踪
forge test -vvv
```

### 查看测试覆盖率

```bash
forge coverage
```

## 📊 测试统计

| 合约          | 测试数量 | 通过数量 | 覆盖功能                 |
| ------------- | -------- | -------- | ------------------------ |
| PlatformToken | 37       | 37       | ERC20 代币完整功能       |
| TicketManager | 45       | 45       | ERC721 门票 NFT 完整功能 |
| **总计**      | **82**   | **82**   | **100%通过率**           |

## 🔧 演示脚本

### PlatformToken 演示

```bash
forge script script/PlatformTokenDemo.s.sol:PlatformTokenDemo
```

### TicketManager 演示

```bash
forge script script/TicketManagerDemo.s.sol:TicketManagerDemo
```

## 📝 测试分类详情

### 1. PlatformToken 测试 (37 个)

#### 部署测试 (2 个测试)

- `test_Deploy()`: 验证合约基本信息（名称、符号、小数位、初始供应量等）
- `test_InitialSupplyMinted()`: 验证初始供应量正确铸造给所有者

#### Mint 功能测试 (5 个测试)

- `test_Mint()`: 测试正常铸造功能
- `test_MintOnlyOwner()`: 验证只有所有者可以铸造
- `test_MintToZeroAddress()`: 防止铸造到零地址
- `test_MintExceedsMaxSupply()`: 防止超过最大供应量
- `test_RemainMintableSupply()`: 测试剩余可铸造供应量计算

#### 批量铸造测试 (5 个测试)

- `test_BatchMint()`: 测试批量铸造功能
- `test_BatchMintArrayLengthMismatch()`: 验证数组长度匹配
- `test_BatchMintTooManyRecipients()`: 限制批量铸造数量（最多 200 个）
- `test_BatchMintZeroAddress()`: 防止批量铸造到零地址
- `test_BatchMintExceedsMaxSupply()`: 防止批量铸造超过最大供应量

#### 销毁功能测试 (6 个测试)

- `test_Burn()`: 测试代币销毁功能
- `test_BurnZeroAmount()`: 防止销毁零数量
- `test_BurnInsufficientBalance()`: 防止销毁超过余额的代币
- `test_BurnFrom()`: 测试授权销毁功能
- `test_BurnFromZeroAmount()`: 防止授权销毁零数量
- `test_BurnFromZeroAddress()`: 防止从零地址销毁
- `test_BurnFromInsufficientAllowance()`: 验证授权额度检查

#### 暂停功能测试 (6 个测试)

- `test_Pause()`: 测试暂停功能
- `test_PauseOnlyOwner()`: 验证只有所有者可以暂停
- `test_Unpause()`: 测试取消暂停功能
- `test_UnpauseOnlyOwner()`: 验证只有所有者可以取消暂停
- `test_TransferWhenPaused()`: 验证暂停时无法转账
- `test_TransferWhenUnpaused()`: 验证取消暂停后可以转账

#### 紧急提取功能测试 (7 个测试)

- `test_EmergencyWithdraw()`: 测试紧急提取功能
- `test_EmergencyWithdrawOnlyOwner()`: 验证只有所有者可以紧急提取
- `test_EmergencyWithdrawSelf()`: 防止提取自身代币
- `test_EmergencyWithdrawToZeroAddress()`: 防止提取到零地址
- `test_EmergencyWithdrawInvalidTokenAddress()`: 防止无效代币地址
- `test_EmergencyWithdrawTokenToItself()`: 防止代币发送给自己
- `test_EmergencyWithdrawInsufficientBalance()`: 验证余额检查

#### ERC20 基础功能测试 (3 个测试)

- `test_Transfer()`: 测试代币转账
- `test_Approve()`: 测试代币授权
- `test_TransferFrom()`: 测试授权转账

#### 模糊测试 (2 个测试)

- `testFuzz_Mint()`: 随机数量铸造测试
- `testFuzz_Burn()`: 随机数量销毁测试

### 2. TicketManager 测试 (45 个)

#### 部署测试 (1 个测试)

- `test_Deploy()`: 验证合约基本信息

#### 权限管理测试 (4 个测试)

- `test_SetMinterAuthorization()`: 设置铸造者授权
- `test_SetMinterAuthorizationOnlyOwner()`: 验证只有所有者可以设置铸造者
- `test_SetVerifierAuthorization()`: 设置验证者授权
- `test_SetVerifierAuthorizationOnlyOwner()`: 验证只有所有者可以设置验证者

#### 门票铸造测试 (8 个测试)

- `test_MintTicket()`: 正常铸造门票功能
- `test_MintTicketUnauthorized()`: 验证未授权用户无法铸造
- `test_MintTicketToZeroAddress()`: 防止铸造到零地址
- `test_MintTicketInvalidTimeRange()`: 验证时间范围有效性
- `test_MintTicketAlreadyExpired()`: 防止铸造已过期门票
- `test_MintTicketSeatAlreadyTaken()`: 防止重复座位号
- `test_MintTicketPurchaseLimitExceeded()`: 验证购买限制
- `test_MintTicketOwnerCanMint()`: 验证所有者可以直接铸造

#### 批量铸造测试 (4 个测试)

- `test_BatchMintTickets()`: 正常批量铸造功能
- `test_BatchMintTicketsEmptyRecipients()`: 防止空收件人数组
- `test_BatchMintTicketsArrayLengthMismatch()`: 验证数组长度匹配
- `test_BatchMintTicketsTooLarge()`: 限制批量大小（最多 100 个）

#### 门票验证与使用测试 (7 个测试)

- `test_UseTicket()`: 正常使用门票功能
- `test_UseTicketUnauthorized()`: 验证未授权用户无法使用门票
- `test_UseTicketNotExists()`: 防止使用不存在的门票
- `test_UseTicketNotValid()`: 防止使用无效状态门票
- `test_UseTicketNotInValidTimeRange()`: 验证时间范围限制
- `test_IsTicketValid()`: 门票有效性检查
- `test_VerifyTicketHash()`: 门票哈希验证

#### 门票管理测试 (5 个测试)

- `test_CancelTicket()`: 取消门票功能
- `test_CancelTicketOnlyOwner()`: 验证只有所有者可以取消门票
- `test_SetTicketTransferable()`: 设置门票转让权限
- `test_SetEventPurchaseLimit()`: 设置活动购买限制
- `test_ExpireTickets()`: 批量过期门票

#### 转移控制测试 (4 个测试)

- `test_TransferTicket()`: 正常转移门票
- `test_TransferNonTransferableTicket()`: 防止转移不可转让门票
- `test_TransferUsedTicket()`: 防止转移已使用门票
- `test_TransferWhenPaused()`: 暂停时禁止转移

#### 查询功能测试 (4 个测试)

- `test_GetEventTickets()`: 获取活动的所有门票
- `test_GetUserEventTickets()`: 获取用户在特定活动的门票
- `test_GetUserTickets()`: 获取用户所有门票
- `test_TokenURI()`: 门票 URI 查询

#### 管理功能测试 (5 个测试)

- `test_Pause()`: 暂停合约功能
- `test_PauseOnlyOwner()`: 验证只有所有者可以暂停
- `test_Unpause()`: 取消暂停功能
- `test_EmergencyWithdrawETH()`: 紧急提取 ETH
- `test_EmergencyWithdrawToZeroAddress()`: 防止提取到零地址

#### ERC721 基础功能测试 (1 个测试)

- `test_SupportsInterface()`: 验证接口支持

#### 边界情况测试 (2 个测试)

- `test_MintTicketWithoutSeat()`: 无座位门票铸造
- `test_MultipleEventsDoNotConflict()`: 不同活动间的座位不冲突

## 🔒 安全检查覆盖

测试用例覆盖了以下安全检查：

### PlatformToken 安全特性

1. **访问控制**: 验证只有授权用户可以执行特定操作
2. **输入验证**: 检查零地址、零数量等无效输入
3. **数量限制**: 验证最大供应量、批量操作限制等
4. **状态检查**: 验证暂停状态、余额检查等
5. **重入攻击防护**: 通过 ReentrancyGuard 保护
6. **授权检查**: 验证 ERC20 授权机制

### TicketManager 安全特性

1. **权限管理**: 铸造者和验证者的授权控制
2. **时间验证**: 门票有效期和使用时间控制
3. **状态管理**: 门票状态变更的正确性
4. **座位唯一性**: 防止同一活动中的座位重复
5. **转移控制**: 基于门票状态和转让权限的转移限制
6. **购买限制**: 用户购买数量的限制控制

## 📈 持续集成

建议在 CI/CD 流程中包含以下测试命令：

```bash
# 编译检查
forge build

# 运行所有测试
forge test

# 检查测试覆盖率
forge coverage

# 运行特定的关键测试
forge test --match-test test_Deploy
forge test --match-test test_Mint
forge test --match-test test_Transfer
```

## 💡 测试最佳实践

1. **命名规范**: 使用清晰的测试函数名称，描述测试的具体场景
2. **独立性**: 每个测试都应该是独立的，不依赖其他测试的状态
3. **覆盖性**: 包含正常情况、边界情况和异常情况的测试
4. **可读性**: 测试代码应该清晰易懂，便于维护
5. **性能**: 关注 gas 使用情况，优化合约性能

## 🔧 故障排除

如果遇到测试失败，请检查：

1. **编译错误**: 确保所有合约都能正确编译
2. **依赖项**: 确保 OpenZeppelin 合约库已正确安装
3. **版本兼容**: 确保 Solidity 版本与合约要求一致
4. **环境配置**: 检查 `foundry.toml` 配置是否正确

## 📚 参考资源

- [Foundry 测试指南](https://book.getfoundry.sh/forge/tests)
- [OpenZeppelin 测试最佳实践](https://docs.openzeppelin.com/test-helpers/)
- [Solidity 测试模式](https://docs.soliditylang.org/en/latest/common-patterns.html)
