#!/bin/bash

# Clash Docker 部署前检查和自动修复脚本
# 确保所有必需的文件和配置都存在

set -e  # 遇到错误立即退出

echo "🔍 Clash Docker 部署前检查开始..."
echo "时间: $(date)"
echo "目录: $(pwd)"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_file() {
    local file="$1"
    local required="$2"
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $file 存在"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}✗${NC} $file 缺失 (必需)"
            return 1
        else
            echo -e "${YELLOW}⚠${NC} $file 缺失 (可选)"
            return 0
        fi
    fi
}

# 创建文件函数
create_file() {
    local source="$1"
    local target="$2"
    local description="$3"
    
    if [[ -f "$source" ]]; then
        echo -e "${BLUE}📄${NC} 从 $source 创建 $target ($description)"
        cp "$source" "$target"
        chmod +x "$target"
        echo -e "${GREEN}✓${NC} $target 创建成功"
    else
        echo -e "${RED}✗${NC} 无法创建 $target，源文件 $source 不存在"
        return 1
    fi
}

error_count=0

echo "=== 1. 检查必需文件 ==="

# 检查Docker配置文件
if ! check_file "compose.yml" true; then
    ((error_count++))
fi

if ! check_file "nginx.conf" true; then
    ((error_count++))
fi

if ! check_file ".env.example" true; then
    ((error_count++))
fi

echo

echo "=== 2. 检查并创建环境文件 ==="

if ! check_file ".env" false; then
    if [[ -f ".env.example" ]]; then
        echo -e "${BLUE}📄${NC} 从 .env.example 创建 .env"
        cp .env.example .env
        echo -e "${GREEN}✓${NC} .env 创建成功"
        echo -e "${YELLOW}⚠${NC} 请编辑 .env 文件设置实际的代理服务器信息"
    else
        echo -e "${RED}✗${NC} 无法创建 .env，.env.example 不存在"
        ((error_count++))
    fi
fi

echo

echo "=== 3. 检查并创建脚本文件 ==="

# 检查scripts目录
if [[ ! -d "scripts" ]]; then
    echo -e "${RED}✗${NC} scripts 目录不存在"
    mkdir -p scripts
    echo -e "${GREEN}✓${NC} scripts 目录已创建"
fi

# 检查必需的配置生成脚本
if ! check_file "scripts/generate-config-universal.sh" false; then
    # 尝试从其他脚本创建
    if [[ -f "scripts/generate-config-advanced.sh" ]]; then
        create_file "scripts/generate-config-advanced.sh" "scripts/generate-config-universal.sh" "通用配置生成脚本"
    elif [[ -f "scripts/generate-config.sh" ]]; then
        create_file "scripts/generate-config.sh" "scripts/generate-config-universal.sh" "通用配置生成脚本"
    else
        echo -e "${RED}✗${NC} 无法创建 generate-config-universal.sh，没有找到源脚本"
        ((error_count++))
    fi
fi

# 检查其他重要脚本
check_file "scripts/health-check.sh" false
check_file "scripts/validate-env.sh" false

echo

echo "=== 4. 检查并创建目录结构 ==="

# 创建必需的目录
directories=("config" "data" "html" "backups/config")

for dir in "${directories[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo -e "${BLUE}📁${NC} 创建目录: $dir"
        mkdir -p "$dir"
        echo -e "${GREEN}✓${NC} $dir 目录已创建"
    else
        echo -e "${GREEN}✓${NC} $dir 目录存在"
    fi
done

echo

echo "=== 5. 验证文件权限 ==="

# 确保脚本有执行权限
script_files=(
    "scripts/generate-config-universal.sh"
    "scripts/generate-config-advanced.sh"
    "scripts/generate-config.sh"
    "scripts/health-check.sh"
    "scripts/validate-env.sh"
)

for script in "${script_files[@]}"; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        echo -e "${GREEN}✓${NC} $script 权限已设置"
    fi
done

echo

echo "=== 6. Docker环境检查 ==="

# 检查Docker
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker 已安装"
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker 服务运行中"
    else
        echo -e "${YELLOW}⚠${NC} Docker 服务未运行，请启动: sudo systemctl start docker"
    fi
else
    echo -e "${RED}✗${NC} Docker 未安装"
    ((error_count++))
fi

# 检查docker-compose
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC} docker-compose 已安装"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC} docker compose (v2) 已安装"
else
    echo -e "${RED}✗${NC} docker-compose 未安装"
    ((error_count++))
fi

echo

echo "=== 7. 网络端口检查 ==="

# 检查端口占用
ports=(7890 7891 8088 9090)
for port in "${ports[@]}"; do
    if netstat -tlpn 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}⚠${NC} 端口 $port 已被占用"
    else
        echo -e "${GREEN}✓${NC} 端口 $port 可用"
    fi
done

echo

echo "=== 检查结果汇总 ==="

if [[ $error_count -eq 0 ]]; then
    echo -e "${GREEN}🎉 所有检查通过！可以安全部署${NC}"
    echo
    echo "建议的部署命令:"
    echo "1. sudo docker-compose up -d"
    echo "2. sudo docker-compose logs -f"
    echo "3. curl http://localhost:8088/config.yaml"
    exit 0
else
    echo -e "${RED}❌ 发现 $error_count 个错误，请修复后重新部署${NC}"
    echo
    echo "修复建议:"
    echo "1. 检查项目文件完整性: git status"
    echo "2. 重新克隆项目: git clone <repo-url>"
    echo "3. 安装缺失的依赖"
    exit 1
fi