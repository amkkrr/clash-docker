#!/bin/bash

set -e

echo "🔄 Starting Clash Docker Hot Reload Service..."

# 创建必要的目录
echo "📁 Creating necessary directories..."
mkdir -p logs/hot-reload
mkdir -p services/hot-reload/logs

# 检查Docker网络
echo "🌐 Checking Docker network..."
if ! docker network ls | grep -q "clash-network"; then
    echo "Creating clash-network..."
    docker network create clash-network
fi

# 构建热重载服务镜像
echo "🏗️ Building hot reload service image..."
docker-compose -f docker-compose.hot-reload.yml build

# 检查配置文件
echo "🔍 Checking configuration files..."
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found"
    echo "Please create .env file first"
    exit 1
fi

if [ ! -f "config/config.yaml" ]; then
    echo "❌ Error: config/config.yaml not found"
    echo "Please ensure config.yaml exists"
    exit 1
fi

# 启动服务
echo "🚀 Starting hot reload service..."
docker-compose -f docker-compose.hot-reload.yml up -d

# 等待服务启动
echo "⏳ Waiting for service to be ready..."
timeout=60
counter=0

while [ $counter -lt $timeout ]; do
    if curl -f http://localhost:8080/health >/dev/null 2>&1; then
        echo "✅ Hot reload service is ready!"
        break
    fi
    
    echo "Waiting... ($counter/$timeout)"
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    echo "❌ Service failed to start within $timeout seconds"
    echo "Checking logs..."
    docker-compose -f docker-compose.hot-reload.yml logs hot-reload
    exit 1
fi

# 显示服务状态
echo "📊 Service Status:"
echo "  HTTP API: http://localhost:8080"
echo "  WebSocket: ws://localhost:8080/ws/config-status"
echo "  Health Check: http://localhost:8080/health"

# 显示监控的文件路径
echo "📁 Monitored Paths:"
curl -s http://localhost:8080/api/watched-paths | jq -r '.paths[]' 2>/dev/null || echo "  Failed to retrieve paths"

echo ""
echo "🎉 Hot reload service started successfully!"
echo "📝 View logs: docker-compose -f docker-compose.hot-reload.yml logs -f hot-reload"
echo "🛑 Stop service: docker-compose -f docker-compose.hot-reload.yml down"