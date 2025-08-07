#!/bin/bash

echo "🚀 启动 OnlineTicket 后端服务"
echo "=========================="

# 检查环境变量文件
if [ ! -f ".env" ]; then
    echo "📋 复制环境变量文件..."
    cp .env.example .env
    echo "⚠️  请编辑 .env 文件，配置正确的数据库和区块链连接信息"
fi

# 检查依赖是否已安装
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
fi

# 检查 Prisma 客户端
echo "🔧 生成 Prisma 客户端..."
npx prisma generate

# 数据库迁移
echo "🗄️  执行数据库迁移..."
npx prisma migrate dev --name init

# 启动开发服务器
echo "🔥 启动开发服务器..."
npm run dev
