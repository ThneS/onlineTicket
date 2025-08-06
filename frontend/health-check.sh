#!/bin/bash

echo "🔍 OnlineTicket Frontend 健康检查"
echo "========================="

# 检查 Node.js 版本
echo "📦 Node.js 版本:"
node --version

# 检查 npm 版本
echo "📦 npm 版本:"
npm --version

# 检查项目文件
echo "📁 项目文件检查:"
if [ -f "package.json" ]; then
    echo "✅ package.json 存在"
else
    echo "❌ package.json 不存在"
fi

if [ -f "vite.config.ts" ]; then
    echo "✅ vite.config.ts 存在"
else
    echo "❌ vite.config.ts 不存在"
fi

if [ -f "tailwind.config.js" ]; then
    echo "✅ tailwind.config.js 存在"
else
    echo "❌ tailwind.config.js 不存在"
fi

# 检查依赖安装
echo "📦 依赖检查:"
if [ -d "node_modules" ]; then
    echo "✅ node_modules 存在"
    echo "📊 依赖数量: $(ls node_modules | wc -l)"
else
    echo "❌ node_modules 不存在，需要运行 npm install"
fi

# 检查源码目录
echo "📂 源码目录检查:"
for dir in "src/components" "src/pages" "src/layout" "src/store" "src/types"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir 存在"
    else
        echo "❌ $dir 不存在"
    fi
done

echo ""
echo "🚀 如果所有检查都通过，可以运行 npm run dev 启动开发服务器"
