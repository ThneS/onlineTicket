#!/bin/bash

echo "🔥 OnlineTicket 前端启动状态检查"
echo "============================="

# 检查开发服务器是否运行
if curl -s http://localhost:5173 > /dev/null; then
    echo "✅ 开发服务器正在运行 (http://localhost:5173)"
else
    echo "❌ 开发服务器未运行"
fi

# 检查关键依赖
echo ""
echo "📦 关键依赖检查:"
dependencies=("react" "wagmi" "viem" "@rainbow-me/rainbowkit" "tailwindcss" "tailwindcss-animate")

for dep in "${dependencies[@]}"; do
    if npm list "$dep" &> /dev/null; then
        version=$(npm list "$dep" --depth=0 2>/dev/null | grep "$dep" | awk '{print $2}' | sed 's/@//g')
        echo "✅ $dep@$version"
    else
        echo "❌ $dep 未安装"
    fi
done

# 检查TypeScript编译
echo ""
echo "🔧 TypeScript 编译检查:"
if npx tsc --noEmit &> /dev/null; then
    echo "✅ TypeScript 编译通过"
else
    echo "⚠️  TypeScript 有编译警告/错误"
fi

# 检查构建
echo ""
echo "🏗️  构建测试:"
if npm run build &> /dev/null; then
    echo "✅ 项目构建成功"
    rm -rf dist 2>/dev/null
else
    echo "❌ 项目构建失败"
fi

echo ""
echo "🎯 总结:"
echo "- 访问地址: http://localhost:5173"
echo "- Web3 支持: Wagmi + Viem + RainbowKit"
echo "- 样式系统: TailwindCSS + shadcn/ui"
echo "- 状态管理: Zustand"

if curl -s http://localhost:5173 > /dev/null; then
    echo ""
    echo "🚀 应用运行正常！你可以开始开发了！"
else
    echo ""
    echo "⚠️  请先运行 'npm run dev' 启动开发服务器"
fi
