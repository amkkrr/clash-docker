#!/bin/bash

set -e

echo "🔄 Starting Clash Docker with Hot Reload Service..."

# 创建必要的目录
echo "📁 Creating necessary directories..."
mkdir -p logs/hot-reload
mkdir -p services/hot-reload/logs

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

# 构建热重载服务镜像
echo "🏗️ Building hot reload service image..."
docker-compose build hot-reload

# 启动完整的服务栈 (包括热重载)
echo "🚀 Starting Clash Docker stack with hot reload..."
docker-compose up -d

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
    echo "❌ Hot reload service failed to start within $timeout seconds"
    echo "Checking logs..."
    docker-compose logs hot-reload
    exit 1
fi

# 显示服务状态
echo "📊 Service Status:"
echo "  Clash HTTP: http://localhost:${CLASH_HTTP_PORT:-7890}"
echo "  Clash SOCKS: socks://localhost:${CLASH_SOCKS_PORT:-7891}"
echo "  Clash Control: http://localhost:${CLASH_CONTROL_PORT:-9090}"
echo "  Nginx Web: http://localhost:${NGINX_PORT:-8088}"
echo "  Hot Reload API: http://localhost:${HOT_RELOAD_PORT:-8080}"
echo "  Hot Reload WebSocket: ws://localhost:${HOT_RELOAD_PORT:-8080}/ws/config-status"

# 显示监控的文件路径
echo "📁 Monitored Paths:"
curl -s http://localhost:${HOT_RELOAD_PORT:-8080}/api/watched-paths | jq -r '.paths[]' 2>/dev/null || echo "  Failed to retrieve paths"

echo ""
echo "🎉 Clash Docker with hot reload started successfully!"
echo "📝 View all logs: docker-compose logs -f"
echo "📝 View hot reload logs: docker-compose logs -f hot-reload"
echo "🛑 Stop services: docker-compose down"