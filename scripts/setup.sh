#!/bin/bash

# Clash Docker 一键设置脚本

set -e

echo "🛡️ Clash Docker 设置向导"
echo "=========================="

# 检查必要文件
if [ ! -f ".env.example" ]; then
    echo "❌ 错误: 未找到 .env.example 文件"
    exit 1
fi

# 1. 复制环境变量模板
if [ ! -f ".env" ]; then
    echo "📋 复制环境变量模板..."
    cp .env.example .env
    echo "✅ 已创建 .env 文件"
else
    echo "⚠️  .env 文件已存在，跳过复制"
fi

# 2. 创建必要目录
echo "📁 创建必要目录..."
mkdir -p config data html scripts

# 3. 设置文件权限
echo "🔐 设置文件权限..."
chmod +x scripts/*.sh 2>/dev/null || true

# 4. 检查Docker环境
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未安装 Docker"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "❌ 错误: 未安装 Docker Compose"
    exit 1
fi

echo "✅ Docker 环境检查通过"

# 5. 提示用户配置
echo ""
echo "📝 下一步操作:"
echo "1. 编辑 .env 文件，配置你的代理信息:"
echo "   nano .env"
echo ""
echo "2. 启动服务:"
echo "   docker compose up -d"
echo ""
echo "3. 访问管理界面:"
echo "   http://localhost (或你配置的端口)"
echo ""
echo "🎉 设置完成! 请按照上述步骤配置你的代理服务器信息。"