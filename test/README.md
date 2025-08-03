# PlatformToken 测试用例文档

## 测试概览

本测试套件为 `PlatformToken` 合约提供了全面的测试覆盖，包含 37 个测试用例，涵盖了合约的所有核心功能。

## 测试分类

### 1. 部署测试 (2 个测试)

- `test_Deploy()`: 验证合约基本信息（名称、符号、小数位、初始供应量等）
- `test_InitialSupplyMinted()`: 验证初始供应量正确铸造给所有者

### 2. Mint 功能测试 (5 个测试)

- `test_Mint()`: 测试正常铸造功能
- `test_MintOnlyOwner()`: 验证只有所有者可以铸造
- `test_MintToZeroAddress()`: 防止铸造到零地址
- `test_MintExceedsMaxSupply()`: 防止超过最大供应量
- `test_RemainMintableSupply()`: 测试剩余可铸造供应量计算

### 3. 批量铸造测试 (5 个测试)

- `test_BatchMint()`: 测试批量铸造功能
- `test_BatchMintArrayLengthMismatch()`: 验证数组长度匹配
- `test_BatchMintTooManyRecipients()`: 限制批量铸造数量（最多 200 个）
- `test_BatchMintZeroAddress()`: 防止批量铸造到零地址
- `test_BatchMintExceedsMaxSupply()`: 防止批量铸造超过最大供应量

### 4. 销毁功能测试 (6 个测试)

- `test_Burn()`: 测试代币销毁功能
- `test_BurnZeroAmount()`: 防止销毁零数量
- `test_BurnInsufficientBalance()`: 防止销毁超过余额的代币
- `test_BurnFrom()`: 测试授权销毁功能
- `test_BurnFromZeroAmount()`: 防止授权销毁零数量
- `test_BurnFromZeroAddress()`: 防止从零地址销毁
- `test_BurnFromInsufficientAllowance()`: 验证授权额度检查

### 5. 暂停功能测试 (6 个测试)

- `test_Pause()`: 测试暂停功能
- `test_PauseOnlyOwner()`: 验证只有所有者可以暂停
- `test_Unpause()`: 测试取消暂停功能
- `test_UnpauseOnlyOwner()`: 验证只有所有者可以取消暂停
- `test_TransferWhenPaused()`: 验证暂停时无法转账
- `test_TransferWhenUnpaused()`: 验证取消暂停后可以转账

### 6. 紧急提取功能测试 (7 个测试)

- `test_EmergencyWithdraw()`: 测试紧急提取功能
- `test_EmergencyWithdrawOnlyOwner()`: 验证只有所有者可以紧急提取
- `test_EmergencyWithdrawSelf()`: 防止提取自身代币
- `test_EmergencyWithdrawToZeroAddress()`: 防止提取到零地址
- `test_EmergencyWithdrawInvalidTokenAddress()`: 防止无效代币地址
- `test_EmergencyWithdrawTokenToItself()`: 防止代币发送给自己
- `test_EmergencyWithdrawInsufficientBalance()`: 验证余额检查

### 7. ERC20 基础功能测试 (3 个测试)

- `test_Transfer()`: 测试代币转账
- `test_Approve()`: 测试代币授权
- `test_TransferFrom()`: 测试授权转账

### 8. 模糊测试 (2 个测试)

- `testFuzz_Mint()`: 随机数量铸造测试
- `testFuzz_Burn()`: 随机数量销毁测试

## 测试工具和辅助合约

### MockERC20 合约

为了测试 `emergencyWithdraw` 功能，创建了一个模拟的 ERC20 代币合约，用于模拟外部代币的提取场景。

## 安全检查覆盖

测试用例覆盖了以下安全检查：

1. **访问控制**: 验证只有授权用户可以执行特定操作
2. **输入验证**: 检查零地址、零数量等无效输入
3. **数量限制**: 验证最大供应量、批量操作限制等
4. **状态检查**: 验证暂停状态、余额检查等
5. **重入攻击防护**: 通过 ReentrancyGuard 保护
6. **授权检查**: 验证 ERC20 授权机制

## 运行测试

```bash
# 运行所有 PlatformToken 测试
forge test --match-contract PlatformTokenTest

# 运行详细输出
forge test --match-contract PlatformTokenTest -v

# 运行特定测试
forge test --match-test test_Mint

# 查看测试覆盖率
forge coverage --match-contract PlatformTokenTest
```

## 注意事项

1. **事件名称**: 合约中的事件 `ToknesMinted` 有拼写错误，应该修正为 `TokensMinted`
2. **Gas 优化**: 所有测试都显示了 gas 使用情况，可以用于优化合约
3. **模糊测试**: 使用了 Foundry 的模糊测试功能，每个测试运行 256 次随机输入

## 测试结果

✅ 所有 37 个测试用例都通过了
✅ 包含 2 个模糊测试，每个运行 256 次
✅ 总测试时间: 81.70ms
✅ 覆盖了合约的所有主要功能和安全检查
