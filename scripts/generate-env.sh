#!/bin/bash

# 环境配置文件生成脚本
# 从 .env.example 生成带有真实UUID的 .env 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_EXAMPLE="$PROJECT_DIR/.env.example"
ENV_OUTPUT="$PROJECT_DIR/.env"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1"; }

# 生成UUID
generate_uuid() {
    python3 -c "import uuid; print(str(uuid.uuid4()))"
}

# 生成随机密码
generate_password() {
    local length=${1:-16}
    python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range($length)))"
}

# 主函数
main() {
    log_info "开始生成环境配置文件..."
    
    # 检查 .env.example 是否存在
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        log_error "模板文件不存在: $ENV_EXAMPLE"
        exit 1
    fi
    
    # 备份现有的 .env 文件
    if [[ -f "$ENV_OUTPUT" ]]; then
        local backup_file="$ENV_OUTPUT.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$ENV_OUTPUT" "$backup_file"
        log_info "已备份现有配置到: $backup_file"
    fi
    
    log_info "生成UUID和密码..."
    
    # 生成UUID
    local jp_direct_uuid=$(generate_uuid)
    local sjc_direct_uuid=$(generate_uuid)
    local sjc_landing_direct_uuid=$(generate_uuid)
    
    # 生成密码（如果需要）
    local clash_secret=$(generate_password 32)
    
    log_info "替换配置模板中的占位符..."
    
    # 复制模板并替换占位符
    cp "$ENV_EXAMPLE" "$ENV_OUTPUT"
    
    # 替换UUID
    sed -i "s/your_vless_uuid/$jp_direct_uuid/g" "$ENV_OUTPUT"
    sed -i "s/your_vmess_uuid/$sjc_direct_uuid/g" "$ENV_OUTPUT"
    sed -i "s/your_landing_vmess_uuid/$sjc_landing_direct_uuid/g" "$ENV_OUTPUT"
    
    # 可选：替换默认密码
    if [[ "${1:-}" == "--generate-passwords" ]]; then
        log_info "生成随机密码..."
        sed -i "s/your_clash_password_here/$clash_secret/g" "$ENV_OUTPUT"
    fi
    
    log_success "环境配置文件已生成: $ENV_OUTPUT"
    log_info "生成的UUID："
    echo "  JP_DIRECT_UUID=$jp_direct_uuid"
    echo "  SJC_DIRECT_UUID=$sjc_direct_uuid"
    echo "  SJC_LANDING_DIRECT_UUID=$sjc_landing_direct_uuid"
    
    if [[ "${1:-}" == "--generate-passwords" ]]; then
        log_info "生成的密码："
        echo "  CLASH_SECRET=$clash_secret"
    fi
    
    log_warn "请编辑 $ENV_OUTPUT 文件，配置其他必要参数："
    log_warn "  - 代理服务器地址和端口"
    log_warn "  - 各种协议的密码"
    log_warn "  - WebSocket路径等"
    
    log_info "配置完成后，运行以下命令验证："
    echo "  ./scripts/validate-env-backup.sh .env"
}

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
    --generate-passwords    同时生成随机密码
    --help                 显示此帮助信息

示例:
    $0                     # 仅生成UUID
    $0 --generate-passwords # 生成UUID和密码

EOF
}

# 脚本入口
case "${1:-}" in
    "--help"|"-h")
        show_usage
        ;;
    *)
        main "$@"
        ;;
esac