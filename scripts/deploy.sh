#!/bin/bash

# Clash Docker 一键自动化部署脚本
# 自动处理所有部署步骤，包括检查、修复、配置和启动

set -e

echo "🚀 Clash Docker 自动化部署脚本"
echo "================================================"
echo "时间: $(date)"
echo "目录: $(pwd)"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/deployment.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

step() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
    log "STEP: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO: $1"
}

# 错误处理
cleanup() {
    if [[ $? -ne 0 ]]; then
        error "部署失败！查看日志: $LOG_FILE"
        echo -e "\n${YELLOW}故障排除建议:${NC}"
        echo "1. 检查 Docker 服务状态: sudo systemctl status docker"
        echo "2. 检查端口占用: netstat -tlpn | grep -E ':(7890|8088|9090)'"
        echo "3. 查看容器日志: sudo docker-compose logs"
        echo "4. 手动清理: sudo docker-compose down -v"
    fi
}
trap cleanup EXIT

# 开始部署
log "========== 开始自动化部署 =========="

step "1. 环境检查"

# 检查是否为root或有sudo权限
if [[ $EUID -eq 0 ]]; then
    SUDO=""
    success "以root用户运行"
elif sudo -n true 2>/dev/null; then
    SUDO="sudo"
    success "有sudo权限"
else
    error "需要root权限或sudo权限"
    exit 1
fi

# 检查Docker
if ! command -v docker &> /dev/null; then
    error "Docker未安装，请先安装Docker"
    exit 1
fi

if ! $SUDO docker info &> /dev/null; then
    warning "Docker服务未运行，正在启动..."
    $SUDO systemctl start docker
    $SUDO systemctl enable docker
    success "Docker服务已启动"
fi

# 检查docker-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif $SUDO docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    error "docker-compose未安装"
    exit 1
fi

success "环境检查完成"

step "2. 项目文件完整性检查和修复"

# 运行预检查脚本
if [[ -f "$SCRIPT_DIR/pre-deploy-check.sh" ]]; then
    info "运行预检查脚本..."
    chmod +x "$SCRIPT_DIR/pre-deploy-check.sh"
    if bash "$SCRIPT_DIR/pre-deploy-check.sh"; then
        success "预检查通过"
    else
        warning "预检查发现问题，继续自动修复..."
    fi
else
    warning "预检查脚本不存在，手动检查文件..."
fi

# 确保关键文件存在
if [[ ! -f "$PROJECT_DIR/.env" ]] && [[ -f "$PROJECT_DIR/.env.example" ]]; then
    info "创建 .env 文件"
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    success ".env 文件已创建"
fi

# 确保配置生成脚本存在
if [[ ! -f "$PROJECT_DIR/scripts/generate-config-universal.sh" ]]; then
    if [[ -f "$PROJECT_DIR/scripts/generate-config-advanced.sh" ]]; then
        info "创建通用配置生成脚本"
        cp "$PROJECT_DIR/scripts/generate-config-advanced.sh" "$PROJECT_DIR/scripts/generate-config-universal.sh"
        chmod +x "$PROJECT_DIR/scripts/generate-config-universal.sh"
        success "配置生成脚本已创建"
    else
        error "找不到配置生成脚本"
        exit 1
    fi
fi

# 创建必要目录
mkdir -p "$PROJECT_DIR"/{config,data,html,backups/config}
success "目录结构检查完成"

step "3. 清理旧的部署"

cd "$PROJECT_DIR"

# 停止现有容器
if $SUDO $COMPOSE_CMD ps -q | grep -q .; then
    info "停止现有容器..."
    $SUDO $COMPOSE_CMD down -v --remove-orphans
    success "旧容器已清理"
fi

# 清理悬挂的镜像和卷
$SUDO docker system prune -f --volumes &> /dev/null || true
success "系统清理完成"

step "4. 配置验证和优化"

# 检查环境变量
if [[ -f ".env" ]]; then
    source .env
    info "环境变量已加载"
    
    # 检查关键配置
    if [[ -z "$CLASH_SECRET" ]] || [[ "$CLASH_SECRET" == "your-secret-here" ]]; then
        warning "CLASH_SECRET 未设置或使用默认值"
        NEW_SECRET="clash-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
        sed -i "s/CLASH_SECRET=.*/CLASH_SECRET=$NEW_SECRET/" .env
        success "已生成新的 CLASH_SECRET: $NEW_SECRET"
    fi
else
    error ".env 文件不存在"
    exit 1
fi

step "5. 拉取最新镜像"

info "拉取Docker镜像..."
$SUDO $COMPOSE_CMD pull
success "镜像拉取完成"

step "6. 启动服务"

info "启动配置生成器..."
$SUDO $COMPOSE_CMD up config-generator

# 检查配置生成结果
if [[ -f "config/config.yaml" ]]; then
    CONFIG_LINES=$(wc -l < config/config.yaml)
    if [[ $CONFIG_LINES -gt 10 ]]; then
        success "配置文件生成成功 ($CONFIG_LINES 行)"
    else
        warning "配置文件可能不完整 (只有 $CONFIG_LINES 行)"
    fi
else
    error "配置文件生成失败"
    $SUDO $COMPOSE_CMD logs config-generator
    exit 1
fi

info "启动所有服务..."
$SUDO $COMPOSE_CMD up -d

# 等待服务启动
sleep 10

step "7. 服务验证"

# 检查容器状态
info "检查容器状态..."
$SUDO $COMPOSE_CMD ps

# 检查服务可用性
SERVICES=(
    "http://localhost:8088/config.yaml:配置文件服务"
    "http://localhost:7890:代理服务(HTTP)"
    "http://localhost:9090/ui:管理界面"
)

for service in "${SERVICES[@]}"; do
    IFS=':' read -r url desc <<< "$service"
    if curl -s --max-time 5 "$url" > /dev/null; then
        success "$desc 可用 ($url)"
    else
        warning "$desc 不可用 ($url)"
    fi
done

step "8. 生成访问信息"

echo -e "\n${GREEN}🎉 部署完成！${NC}"
echo -e "\n${CYAN}服务信息:${NC}"
echo "• HTTP代理: http://$(hostname -I | awk '{print $1}'):7890"
echo "• SOCKS代理: socks5://$(hostname -I | awk '{print $1}'):7891"
echo "• 配置文件: http://$(hostname -I | awk '{print $1}'):8088/config.yaml"
echo "• 管理界面: http://$(hostname -I | awk '{print $1}'):9090/ui"
echo "• 管理密钥: $CLASH_SECRET"

echo -e "\n${CYAN}配置使用:${NC}"
echo "1. 代理设置: HTTP代理地址填入客户端"
echo "2. 订阅地址: 配置文件URL可用作订阅链接"
echo "3. 管理界面: 使用密钥登录管理界面"

echo -e "\n${CYAN}常用命令:${NC}"
echo "• 查看日志: $SUDO $COMPOSE_CMD logs -f"
echo "• 重启服务: $SUDO $COMPOSE_CMD restart"
echo "• 停止服务: $SUDO $COMPOSE_CMD down"
echo "• 更新配置: $SUDO $COMPOSE_CMD up -d config-generator"

echo -e "\n${CYAN}文件位置:${NC}"
echo "• 项目目录: $PROJECT_DIR"
echo "• 配置文件: $PROJECT_DIR/config/config.yaml"
echo "• 环境配置: $PROJECT_DIR/.env"
echo "• 部署日志: $LOG_FILE"

log "========== 部署完成 =========="

# 提供故障排除信息
cat > "$PROJECT_DIR/troubleshooting.md" << 'EOF'
# Clash Docker 故障排除指南

## 常见问题

### 1. 配置文件只显示 mixed-port: 7890
```bash
# 重新生成配置
sudo docker-compose up config-generator
sudo docker-compose logs config-generator
```

### 2. 代理连接失败
```bash
# 检查服务状态
sudo docker-compose ps
curl http://localhost:7890
```

### 3. 管理界面无法访问
```bash
# 检查端口和密钥
curl http://localhost:9090/ui
echo "密钥: $CLASH_SECRET"
```

### 4. 容器启动失败
```bash
# 查看详细日志
sudo docker-compose logs
sudo docker-compose down -v
sudo docker-compose up -d
```

## 重新部署
```bash
# 完全重新部署
./scripts/deploy.sh
```
EOF

success "故障排除指南已生成: $PROJECT_DIR/troubleshooting.md"