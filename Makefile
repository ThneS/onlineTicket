# OnlineTicket 项目部署和管理 Makefile

# 默认网络设置
NETWORK ?= anvil
RPC_URL ?= http://127.0.0.1:8545
PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 合约地址环境变量（部署后设置）
PLATFORM_TOKEN_ADDRESS ?=
TICKET_MANAGER_ADDRESS ?=
EVENT_MANAGER_ADDRESS ?=
TOKEN_SWAP_ADDRESS ?=
MARKETPLACE_ADDRESS ?=

# 颜色定义
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help build test deploy-quick deploy-full demo manage clean

# 默认目标
help:
	@echo "$(GREEN)OnlineTicket 项目部署和管理工具$(NC)"
	@echo ""
	@echo "$(YELLOW)构建和测试:$(NC)"
	@echo "  make build          - 编译所有合约"
	@echo "  make test           - 运行所有测试"
	@echo "  make test-verbose   - 运行详细测试"
	@echo "  make coverage       - 生成测试覆盖率报告"
	@echo ""
	@echo "$(YELLOW)部署操作:$(NC)"
	@echo "  make deploy-quick   - 快速部署到本地网络"
	@echo "  make deploy-full    - 完整部署（带初始配置）"
	@echo "  make deploy-testnet - 部署到测试网"
	@echo ""
	@echo "$(YELLOW)演示和管理:$(NC)"
	@echo "  make demo          - 运行完整功能演示"
	@echo "  make status        - 查看系统状态"
	@echo "  make verify        - 验证部署结果"
	@echo "  make authorize     - 授权新用户"
	@echo "  make add-liquidity - 添加流动性"
	@echo ""
	@echo "$(YELLOW)维护操作:$(NC)"
	@echo "  make pause-all     - 暂停所有合约"
	@echo "  make unpause-all   - 恢复所有合约"
	@echo "  make clean         - 清理构建文件"
	@echo ""
	@echo "$(YELLOW)环境设置:$(NC)"
	@echo "  NETWORK=anvil|sepolia|mainnet"
	@echo "  PRIVATE_KEY=你的私钥"

# 构建和测试
build:
	@echo "$(GREEN)编译合约...$(NC)"
	forge build

test:
	@echo "$(GREEN)运行测试...$(NC)"
	forge test

test-verbose:
	@echo "$(GREEN)运行详细测试...$(NC)"
	forge test -vvv

test-gas:
	@echo "$(GREEN)运行Gas报告测试...$(NC)"
	forge test --gas-report

coverage:
	@echo "$(GREEN)生成测试覆盖率...$(NC)"
	forge coverage

# 清理
clean:
	@echo "$(GREEN)清理构建文件...$(NC)"
	forge clean
	rm -rf cache/ out/

# 部署操作
deploy-quick:
	@echo "$(GREEN)快速部署到 $(NETWORK)...$(NC)"
	@if [ "$(NETWORK)" = "anvil" ]; then \
		echo "$(YELLOW)确保 Anvil 正在运行: anvil$(NC)"; \
	fi
	forge script script/QuickDeploy.s.sol:QuickDeploy \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast

# 演示和管理
demo:
	@echo "$(GREEN)运行完整功能演示...$(NC)"
	@if [ -z "$(PLATFORM_TOKEN_ADDRESS)" ]; then \
		echo "$(RED)错误: 请先设置合约地址环境变量$(NC)"; \
		echo "使用 'make deploy-quick' 部署后设置地址"; \
		exit 1; \
	fi
	PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
	TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
	EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
	TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
	MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
	forge script script/DemoScript.s.sol:DemoScript \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast

status:
	@echo "$(GREEN)查看系统状态...$(NC)"
	@if [ -z "$(PLATFORM_TOKEN_ADDRESS)" ]; then \
		echo "$(RED)错误: 请先设置合约地址环境变量$(NC)"; \
		exit 1; \
	fi
	PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
	TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
	EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
	TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
	MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
	forge script script/ManageContracts.s.sol:ManageContracts \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--sig "getSystemStatus()"

# 权限管理
authorize:
	@echo "$(GREEN)授权用户...$(NC)"
	@read -p "输入要授权的地址: " ADDRESS; \
	PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
	TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
	EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
	TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
	MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
	forge script script/ManageContracts.s.sol:ManageContracts \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--sig "authorizeOrganizer(address)" $$ADDRESS \
		--broadcast

# 添加流动性
add-liquidity:
	@echo "$(GREEN)添加流动性...$(NC)"
	@read -p "输入代币数量 (整数，如 1000): " TOKEN_AMOUNT; \
	read -p "输入ETH数量 (如 1): " ETH_AMOUNT; \
	PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
	TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
	EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
	TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
	MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
	forge script script/ManageContracts.s.sol:ManageContracts \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--sig "addLiquidity(uint256,uint256)" $$(($${TOKEN_AMOUNT} * 1000000000000000000)) $$(echo "$$ETH_AMOUNT * 1000000000000000000" | bc | cut -d. -f1) \
		--broadcast

# 紧急操作
pause-all:
	@echo "$(RED)暂停所有合约...$(NC)"
	@read -p "确认暂停所有合约? (y/N): " CONFIRM; \
	if [ "$$CONFIRM" = "y" ]; then \
		PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
		TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
		EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
		TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
		MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
		forge script script/ManageContracts.s.sol:ManageContracts \
			--rpc-url $(RPC_URL) \
			--private-key $(PRIVATE_KEY) \
			--sig "pauseAll()" \
			--broadcast; \
	fi

unpause-all:
	@echo "$(GREEN)恢复所有合约...$(NC)"
	@read -p "确认恢复所有合约? (y/N): " CONFIRM; \
	if [ "$$CONFIRM" = "y" ]; then \
		PLATFORM_TOKEN_ADDRESS=$(PLATFORM_TOKEN_ADDRESS) \
		TICKET_MANAGER_ADDRESS=$(TICKET_MANAGER_ADDRESS) \
		EVENT_MANAGER_ADDRESS=$(EVENT_MANAGER_ADDRESS) \
		TOKEN_SWAP_ADDRESS=$(TOKEN_SWAP_ADDRESS) \
		MARKETPLACE_ADDRESS=$(MARKETPLACE_ADDRESS) \
		forge script script/ManageContracts.s.sol:ManageContracts \
			--rpc-url $(RPC_URL) \
			--private-key $(PRIVATE_KEY) \
			--sig "unpauseAll()" \
			--broadcast; \
	fi

# 网络特定的快捷命令
anvil-start:
	@echo "$(GREEN)启动 Anvil 本地网络...$(NC)"
	anvil --host 0.0.0.0 --port 8545

anvil-deploy:
	@echo "$(GREEN)部署到本地 Anvil...$(NC)"
	$(MAKE) deploy-quick NETWORK=anvil

sepolia-deploy:
	@echo "$(GREEN)部署到 Sepolia 测试网...$(NC)"
	@if [ -z "$$SEPOLIA_RPC_URL" ]; then \
		echo "$(RED)请设置 SEPOLIA_RPC_URL 环境变量$(NC)"; \
		exit 1; \
	fi
	$(MAKE) deploy-testnet NETWORK=sepolia RPC_URL=$$SEPOLIA_RPC_URL

# 环境变量模板
env-template:
	@echo "$(YELLOW)创建环境变量模板...$(NC)"
	@echo "# 网络配置" > .env.example
	@echo "PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" >> .env.example
	@echo "ANVIL_RPC_URL=http://127.0.0.1:8545" >> .env.example
	@echo "SEPOLIA_RPC_URL=https://ethereum-sepolia.publicnode.com" >> .env.example
	@echo "MAINNET_RPC_URL=https://ethereum.publicnode.com" >> .env.example
	@echo "" >> .env.example
	@echo "# 合约地址 (部署后填写)" >> .env.example
	@echo "PLATFORM_TOKEN_ADDRESS=" >> .env.example
	@echo "TICKET_MANAGER_ADDRESS=" >> .env.example
	@echo "EVENT_MANAGER_ADDRESS=" >> .env.example
	@echo "TOKEN_SWAP_ADDRESS=" >> .env.example
	@echo "MARKETPLACE_ADDRESS=" >> .env.example
	@echo "" >> .env.example
	@echo "# Etherscan API (用于验证)" >> .env.example
	@echo "ETHERSCAN_API_KEY=" >> .env.example
	@echo "$(GREEN)环境变量模板已创建: .env.example$(NC)"
	@echo "$(YELLOW)请复制并编辑为 .env 文件$(NC)"

# 完整的开发流程
dev-setup:
	@echo "$(GREEN)设置开发环境...$(NC)"
	$(MAKE) env-template
	$(MAKE) build
	$(MAKE) test
	@echo "$(GREEN)开发环境设置完成!$(NC)"
	@echo "$(YELLOW)下一步:$(NC)"
	@echo "1. 编辑 .env 文件"
	@echo "2. 运行 'anvil' 启动本地网络"
	@echo "3. 运行 'make anvil-deploy' 部署合约"

dev-flow:
	@echo "$(GREEN)完整开发流程...$(NC)"
	$(MAKE) clean
	$(MAKE) build
	$(MAKE) test
	$(MAKE) anvil-deploy
	@echo "$(GREEN)开发流程完成!$(NC)"

# 验证部署
verify:
	@echo "$(GREEN)验证部署结果...$(NC)"
	./verify-deployment.sh

# 显示重要信息
info:
	@echo "$(GREEN)OnlineTicket 项目信息$(NC)"
	@echo "项目结构:"
	@echo "  src/           - 智能合约源码"
	@echo "  test/          - 测试文件"
	@echo "  script/        - 部署脚本"
	@echo ""
	@echo "主要合约:"
	@echo "  PlatformToken  - ERC20 平台代币"
	@echo "  TicketManager  - ERC721 门票 NFT"
	@echo "  EventManager   - 活动管理"
	@echo "  TokenSwap      - AMM 代币交换"
	@echo "  Marketplace    - 二级市场"
	@echo ""
	@echo "$(YELLOW)开始使用:$(NC)"
	@echo "  make dev-setup    - 初次设置"
	@echo "  make anvil-deploy - 部署到本地"
	@echo "  make demo        - 运行演示"
