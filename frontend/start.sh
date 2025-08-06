#!/bin/bash

echo "🚀 启动 OnlineTicket 前端开发环境"
echo "================================"

# 检查依赖是否已安装
if [ ! -d "node_modules" ]; then
    echo "📦 正在安装依赖..."
    npm install
fi

echo "🔥 启动开发服务器..."
npm run dev
