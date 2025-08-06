#!/bin/bash

# 部署验证脚本
# 检查合约是否正确部署并关联

echo "=== OnlineTicket 部署验证 ==="

# 加载环境变量
if [ -f .env ]; then
    source .env
else
    echo "使用默认的本地测试合约地址"
    export PLATFORM_TOKEN_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"
    export TICKET_MANAGER_ADDRESS="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
    export EVENT_MANAGER_ADDRESS="0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
    export TOKEN_SWAP_ADDRESS="0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
    export MARKETPLACE_ADDRESS="0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
    export RPC_URL="http://127.0.0.1:8545"
fi

echo "1. 检查合约代码..."
echo "PlatformToken: $PLATFORM_TOKEN_ADDRESS"
cast code $PLATFORM_TOKEN_ADDRESS --rpc-url $RPC_URL | head -c 20
echo "..."

echo -e "\nTicketManager: $TICKET_MANAGER_ADDRESS"
cast code $TICKET_MANAGER_ADDRESS --rpc-url $RPC_URL | head -c 20
echo "..."

echo -e "\n2. 检查合约关联..."
echo "EventManager 中的 TicketManager 地址:"
cast call $EVENT_MANAGER_ADDRESS "ticketManager()" --rpc-url $RPC_URL

echo -e "\nEventManager 中的 PlatformToken 地址:"
cast call $EVENT_MANAGER_ADDRESS "platformToken()" --rpc-url $RPC_URL

echo -e "\n3. 检查权限设置..."
echo "EventManager 是否为授权铸造者:"
cast call $TICKET_MANAGER_ADDRESS "authorizedMinters(address)" $EVENT_MANAGER_ADDRESS --rpc-url $RPC_URL

echo -e "\nMarketplace 是否为授权铸造者:"
cast call $TICKET_MANAGER_ADDRESS "authorizedMinters(address)" $MARKETPLACE_ADDRESS --rpc-url $RPC_URL

echo -e "\n4. 检查代币信息..."
echo "代币名称:"
cast call $PLATFORM_TOKEN_ADDRESS "name()" --rpc-url $RPC_URL

echo -e "\n代币符号:"
cast call $PLATFORM_TOKEN_ADDRESS "symbol()" --rpc-url $RPC_URL

echo -e "\n总供应量:"
cast call $PLATFORM_TOKEN_ADDRESS "totalSupply()" --rpc-url $RPC_URL

echo -e "\n=== 验证完成 ==="
