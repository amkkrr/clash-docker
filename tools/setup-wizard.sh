#!/bin/bash

# Clash Docker 安装向导
# 交互式配置生成和部署工具

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# 配置变量
declare -A CONFIG
ENV_FILE="$PROJECT_DIR/.env"
DEPLOYMENT_MODE=""
ENABLE_MONITORING=false
ENABLE_SECURITY=false

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Clash Docker 安装向导                    ║${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${CYAN}║        🚀 企业级代理服务部署解决方案                   ║${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${CYAN}║  本向导将帮助您配置和部署 Clash Docker 服务            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "当前项目目录: $PROJECT_DIR"
    echo ""
    
    read -p "按回车键开始配置..." -r
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."
    
    local missing_deps=()
    
    # 检查 Docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    else
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        log_info "Docker 版本: $docker_version"
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    else
        if docker compose version >/dev/null 2>&1; then
            local compose_version=$(docker compose version --short)
            log_info "Docker Compose 版本: $compose_version"
        else
            local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
            log_info "Docker Compose 版本: $compose_version"
        fi
    fi
    
    # 检查其他依赖
    for cmd in curl jq python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少以下依赖项: ${missing_deps[*]}"
        echo ""
        echo "请先安装缺少的依赖项："
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install ${missing_deps[*]}"
        echo "  CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        echo "  macOS: brew install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "系统要求检查通过"
}

# 选择部署模式
select_deployment_mode() {
    log_step "选择部署模式"
    echo ""
    echo "请选择部署模式："
    echo "  1) 基础模式 - 最小配置，适合个人使用"
    echo "  2) 标准模式 - 平衡配置，适合小团队"
    echo "  3) 企业模式 - 完整功能，适合企业环境"
    echo "  4) 安全模式 - 加固配置，适合高安全要求"
    echo "  5) 开发模式 - 调试配置，适合开发测试"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-5): " -r choice
        case $choice in
            1)
                DEPLOYMENT_MODE="basic"
                log_info "已选择: 基础模式"
                break
                ;;
            2)
                DEPLOYMENT_MODE="standard"
                ENABLE_MONITORING=true
                log_info "已选择: 标准模式 (包含监控)"
                break
                ;;
            3)
                DEPLOYMENT_MODE="enterprise"
                ENABLE_MONITORING=true
                ENABLE_SECURITY=true
                log_info "已选择: 企业模式 (包含监控和安全加固)"
                break
                ;;
            4)
                DEPLOYMENT_MODE="security"
                ENABLE_SECURITY=true
                log_info "已选择: 安全模式 (启用所有安全特性)"
                break
                ;;
            5)
                DEPLOYMENT_MODE="development"
                log_info "已选择: 开发模式"
                break
                ;;
            *)
                log_error "无效选择，请输入 1-5"
                ;;
        esac
    done
}

# 配置基础设置
configure_basic_settings() {
    log_step "配置基础设置"
    echo ""
    
    # 服务端口配置
    echo "=== 服务端口配置 ==="
    read -p "Clash HTTP 代理端口 [7890]: " -r http_port
    CONFIG[CLASH_HTTP_PORT]=${http_port:-7890}
    
    read -p "Clash SOCKS5 代理端口 [7891]: " -r socks_port
    CONFIG[CLASH_SOCKS_PORT]=${socks_port:-7891}
    
    read -p "Clash 控制端口 [9090]: " -r control_port
    CONFIG[CLASH_CONTROL_PORT]=${control_port:-9090}
    
    read -p "Nginx Web 端口 [8088]: " -r nginx_port
    CONFIG[NGINX_PORT]=${nginx_port:-8088}
    
    # 基础配置
    echo ""
    echo "=== 基础配置 ==="
    read -p "Clash 运行模式 (rule/global/direct) [rule]: " -r clash_mode
    CONFIG[CLASH_MODE]=${clash_mode:-rule}
    
    read -p "日志级别 (debug/info/warning/error) [info]: " -r log_level
    CONFIG[CLASH_LOG_LEVEL]=${log_level:-info}
    
    read -p "是否允许局域网访问 (true/false) [false]: " -r allow_lan
    CONFIG[CLASH_ALLOW_LAN]=${allow_lan:-false}
    
    # 生成随机密钥
    local secret=$(openssl rand -hex 16 2>/dev/null || echo "clash-$(date +%s)")
    CONFIG[CLASH_SECRET]=$secret
    log_info "已生成API密钥: ${secret:0:8}..."
}

# 配置代理服务器
configure_proxy_servers() {
    log_step "配置代理服务器"
    echo ""
    
    local proxy_count=1
    
    while true; do
        echo "=== 配置代理服务器 #$proxy_count ==="
        
        read -p "代理名称 [节点$proxy_count]: " -r proxy_name
        CONFIG["PROXY_NAME_$proxy_count"]=${proxy_name:-"节点$proxy_count"}
        
        echo "支持的代理类型："
        echo "  1) Shadowsocks (ss)"
        echo "  2) VMess (vmess)"  
        echo "  3) Trojan (trojan)"
        echo "  4) SOCKS5 (socks5)"
        echo "  5) HTTP (http)"
        
        while true; do
            read -p "选择代理类型 (1-5): " -r proxy_type_choice
            case $proxy_type_choice in
                1) CONFIG["PROXY_TYPE_$proxy_count"]="ss"; break ;;
                2) CONFIG["PROXY_TYPE_$proxy_count"]="vmess"; break ;;
                3) CONFIG["PROXY_TYPE_$proxy_count"]="trojan"; break ;;
                4) CONFIG["PROXY_TYPE_$proxy_count"]="socks5"; break ;;
                5) CONFIG["PROXY_TYPE_$proxy_count"]="http"; break ;;
                *) log_error "无效选择" ;;
            esac
        done
        
        read -p "服务器地址: " -r proxy_server
        CONFIG["PROXY_SERVER_$proxy_count"]=$proxy_server
        
        read -p "服务器端口: " -r proxy_port
        CONFIG["PROXY_PORT_$proxy_count"]=$proxy_port
        
        # 根据代理类型配置特定参数
        case "${CONFIG["PROXY_TYPE_$proxy_count"]}" in
            "ss")
                read -p "密码: " -r proxy_password
                CONFIG["PROXY_PASSWORD_$proxy_count"]=$proxy_password
                
                echo "加密方式选择："
                echo "  1) aes-256-gcm (推荐)"
                echo "  2) aes-128-gcm"
                echo "  3) chacha20-ietf-poly1305"
                
                read -p "选择加密方式 (1-3) [1]: " -r cipher_choice
                case ${cipher_choice:-1} in
                    1) CONFIG["PROXY_CIPHER_$proxy_count"]="aes-256-gcm" ;;
                    2) CONFIG["PROXY_CIPHER_$proxy_count"]="aes-128-gcm" ;;
                    3) CONFIG["PROXY_CIPHER_$proxy_count"]="chacha20-ietf-poly1305" ;;
                esac
                ;;
            "vmess")
                read -p "UUID: " -r proxy_uuid
                CONFIG["PROXY_UUID_$proxy_count"]=$proxy_uuid
                
                read -p "AlterID [0]: " -r proxy_alterid
                CONFIG["PROXY_ALTERID_$proxy_count"]=${proxy_alterid:-0}
                
                read -p "是否启用TLS (true/false) [true]: " -r proxy_tls
                CONFIG["PROXY_TLS_$proxy_count"]=${proxy_tls:-true}
                ;;
            "trojan")
                read -p "密码: " -r proxy_password
                CONFIG["PROXY_PASSWORD_$proxy_count"]=$proxy_password
                
                read -p "SNI (可选): " -r proxy_sni
                [[ -n "$proxy_sni" ]] && CONFIG["PROXY_SNI_$proxy_count"]=$proxy_sni
                ;;
            "socks5"|"http")
                read -p "用户名 (可选): " -r proxy_username
                [[ -n "$proxy_username" ]] && CONFIG["PROXY_USERNAME_$proxy_count"]=$proxy_username
                
                read -p "密码 (可选): " -r proxy_password
                [[ -n "$proxy_password" ]] && CONFIG["PROXY_PASSWORD_$proxy_count"]=$proxy_password
                ;;
        esac
        
        echo ""
        read -p "是否继续添加代理服务器? (y/n) [n]: " -r add_more
        if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
            break
        fi
        
        ((proxy_count++))
        echo ""
    done
    
    CONFIG[PROXY_COUNT]=$proxy_count
    log_success "已配置 $proxy_count 个代理服务器"
}

# 安全配置
configure_security() {
    if [[ "$ENABLE_SECURITY" != "true" ]]; then
        return
    fi
    
    log_step "配置安全设置"
    echo ""
    
    echo "=== 认证配置 ==="
    read -p "管理员用户名 [admin]: " -r auth_user
    CONFIG[NGINX_AUTH_USER]=${auth_user:-admin}
    
    # 生成随机密码
    local default_password=$(openssl rand -base64 12 2>/dev/null || echo "clash123456")
    read -p "管理员密码 [$default_password]: " -r auth_password
    CONFIG[NGINX_AUTH_PASS]=${auth_password:-$default_password}
    
    echo ""
    echo "=== 网络访问控制 ==="
    read -p "绑定地址 [127.0.0.1]: " -r bind_address
    CONFIG[BIND_ADDRESS]=${bind_address:-127.0.0.1}
    
    read -p "启用IP白名单 (y/n) [y]: " -r enable_whitelist
    if [[ "$enable_whitelist" =~ ^[Yy]$ ]]; then
        CONFIG[NGINX_WHITELIST_ENABLED]=true
        read -p "允许的IP地址 (逗号分隔) [127.0.0.1,10.0.0.0/8]: " -r whitelist_ips
        CONFIG[NGINX_WHITELIST_IPS]=${whitelist_ips:-"127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"}
    fi
    
    read -p "启用访问限流 (y/n) [y]: " -r enable_rate_limit
    if [[ "$enable_rate_limit" =~ ^[Yy]$ ]]; then
        CONFIG[NGINX_RATE_LIMIT]=true
        read -p "限制频率 [5r/s]: " -r rate_limit
        CONFIG[NGINX_RATE_LIMIT_RATE]=${rate_limit:-"5r/s"}
    fi
}

# 监控配置
configure_monitoring() {
    if [[ "$ENABLE_MONITORING" != "true" ]]; then
        return
    fi
    
    log_step "配置监控设置"
    echo ""
    
    read -p "启用健康检查 (y/n) [y]: " -r enable_health_check
    if [[ "$enable_health_check" =~ ^[Yy]$ ]]; then
        CONFIG[HEALTH_CHECK_ENABLED]=true
        read -p "检查间隔(秒) [30]: " -r health_interval
        CONFIG[HEALTH_CHECK_INTERVAL]=${health_interval:-30}
    fi
    
    read -p "启用指标收集 (y/n) [y]: " -r enable_metrics
    if [[ "$enable_metrics" =~ ^[Yy]$ ]]; then
        CONFIG[METRICS_ENABLED]=true
        read -p "指标端口 [9091]: " -r metrics_port
        CONFIG[METRICS_PORT]=${metrics_port:-9091}
    fi
    
    read -p "启用详细日志 (y/n) [y]: " -r enable_detailed_logs
    if [[ "$enable_detailed_logs" =~ ^[Yy]$ ]]; then
        CONFIG[LOG_TO_FILE]=true
        CONFIG[NGINX_ACCESS_LOG]=true
    fi
}

# 生成环境变量文件
generate_env_file() {
    log_step "生成环境变量文件"
    
    local backup_env=""
    if [[ -f "$ENV_FILE" ]]; then
        backup_env="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "$backup_env"
        log_warn "已备份现有配置到: $backup_env"
    fi
    
    cat > "$ENV_FILE" << EOF
# Clash Docker 配置文件
# 由安装向导自动生成于 $(date)
# 部署模式: $DEPLOYMENT_MODE

# 基础服务配置
CLASH_HTTP_PORT=${CONFIG[CLASH_HTTP_PORT]}
CLASH_SOCKS_PORT=${CONFIG[CLASH_SOCKS_PORT]}
CLASH_CONTROL_PORT=${CONFIG[CLASH_CONTROL_PORT]}
NGINX_PORT=${CONFIG[NGINX_PORT]}

# Clash 核心配置
CLASH_MODE=${CONFIG[CLASH_MODE]}
CLASH_LOG_LEVEL=${CONFIG[CLASH_LOG_LEVEL]}
CLASH_ALLOW_LAN=${CONFIG[CLASH_ALLOW_LAN]}
CLASH_SECRET=${CONFIG[CLASH_SECRET]}

EOF

    # 添加代理配置
    echo "# 代理服务器配置" >> "$ENV_FILE"
    for ((i=1; i<=${CONFIG[PROXY_COUNT]}; i++)); do
        echo "PROXY_NAME_$i=${CONFIG["PROXY_NAME_$i"]}" >> "$ENV_FILE"
        echo "PROXY_TYPE_$i=${CONFIG["PROXY_TYPE_$i"]}" >> "$ENV_FILE"
        echo "PROXY_SERVER_$i=${CONFIG["PROXY_SERVER_$i"]}" >> "$ENV_FILE"
        echo "PROXY_PORT_$i=${CONFIG["PROXY_PORT_$i"]}" >> "$ENV_FILE"
        
        # 根据类型添加特定配置
        case "${CONFIG["PROXY_TYPE_$i"]}" in
            "ss")
                echo "PROXY_PASSWORD_$i=${CONFIG["PROXY_PASSWORD_$i"]}" >> "$ENV_FILE"
                echo "PROXY_CIPHER_$i=${CONFIG["PROXY_CIPHER_$i"]}" >> "$ENV_FILE"
                ;;
            "vmess")
                echo "PROXY_UUID_$i=${CONFIG["PROXY_UUID_$i"]}" >> "$ENV_FILE"
                echo "PROXY_ALTERID_$i=${CONFIG["PROXY_ALTERID_$i"]}" >> "$ENV_FILE"
                [[ -n "${CONFIG["PROXY_TLS_$i"]:-}" ]] && echo "PROXY_TLS_$i=${CONFIG["PROXY_TLS_$i"]}" >> "$ENV_FILE"
                ;;
            "trojan")
                echo "PROXY_PASSWORD_$i=${CONFIG["PROXY_PASSWORD_$i"]}" >> "$ENV_FILE"
                [[ -n "${CONFIG["PROXY_SNI_$i"]:-}" ]] && echo "PROXY_SNI_$i=${CONFIG["PROXY_SNI_$i"]}" >> "$ENV_FILE"
                ;;
            "socks5"|"http")
                [[ -n "${CONFIG["PROXY_USERNAME_$i"]:-}" ]] && echo "PROXY_USERNAME_$i=${CONFIG["PROXY_USERNAME_$i"]}" >> "$ENV_FILE"
                [[ -n "${CONFIG["PROXY_PASSWORD_$i"]:-}" ]] && echo "PROXY_PASSWORD_$i=${CONFIG["PROXY_PASSWORD_$i"]}" >> "$ENV_FILE"
                ;;
        esac
        echo "" >> "$ENV_FILE"
    done
    
    # 添加安全配置
    if [[ "$ENABLE_SECURITY" == "true" ]]; then
        cat >> "$ENV_FILE" << EOF
# 安全配置
NGINX_AUTH_USER=${CONFIG[NGINX_AUTH_USER]}
NGINX_AUTH_PASS=${CONFIG[NGINX_AUTH_PASS]}
BIND_ADDRESS=${CONFIG[BIND_ADDRESS]}
EOF
        
        if [[ "${CONFIG[NGINX_WHITELIST_ENABLED]:-}" == "true" ]]; then
            echo "NGINX_WHITELIST_ENABLED=true" >> "$ENV_FILE"
            echo "NGINX_WHITELIST_IPS=${CONFIG[NGINX_WHITELIST_IPS]}" >> "$ENV_FILE"
        fi
        
        if [[ "${CONFIG[NGINX_RATE_LIMIT]:-}" == "true" ]]; then
            echo "NGINX_RATE_LIMIT=true" >> "$ENV_FILE"
            echo "NGINX_RATE_LIMIT_RATE=${CONFIG[NGINX_RATE_LIMIT_RATE]}" >> "$ENV_FILE"
        fi
        
        echo "" >> "$ENV_FILE"
    fi
    
    # 添加监控配置
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        cat >> "$ENV_FILE" << EOF
# 监控配置
HEALTH_CHECK_ENABLED=${CONFIG[HEALTH_CHECK_ENABLED]:-true}
HEALTH_CHECK_INTERVAL=${CONFIG[HEALTH_CHECK_INTERVAL]:-30}
METRICS_ENABLED=${CONFIG[METRICS_ENABLED]:-true}
METRICS_PORT=${CONFIG[METRICS_PORT]:-9091}
LOG_TO_FILE=${CONFIG[LOG_TO_FILE]:-true}
NGINX_ACCESS_LOG=${CONFIG[NGINX_ACCESS_LOG]:-true}

EOF
    fi
    
    log_success "环境变量文件已生成: $ENV_FILE"
}

# 选择部署方式
select_deployment_method() {
    log_step "选择部署方式"
    echo ""
    
    echo "请选择部署方式："
    echo "  1) 立即部署 - 现在就启动服务"
    echo "  2) 仅生成配置 - 稍后手动部署"
    echo "  3) 测试部署 - 验证配置后部署"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-3): " -r deploy_choice
        case $deploy_choice in
            1)
                deploy_services
                break
                ;;
            2)
                show_manual_deployment_instructions
                break
                ;;
            3)
                test_and_deploy
                break
                ;;
            *)
                log_error "无效选择，请输入 1-3"
                ;;
        esac
    done
}

# 部署服务
deploy_services() {
    log_step "部署服务"
    echo ""
    
    # 生成配置
    log_info "生成 Clash 配置文件..."
    if ! "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate; then
        log_error "配置生成失败"
        return 1
    fi
    
    # 选择Docker Compose文件
    local compose_files=("-f" "$PROJECT_DIR/compose.yml")
    
    if [[ "$ENABLE_SECURITY" == "true" ]]; then
        compose_files+=("-f" "$PROJECT_DIR/security/compose.secure.yml")
        log_info "启用安全加固配置"
    fi
    
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        compose_files+=("-f" "$PROJECT_DIR/monitoring/compose.monitoring.yml")
        log_info "启用监控服务"
    fi
    
    # 启动服务
    log_info "启动服务..."
    if docker compose "${compose_files[@]}" up -d; then
        log_success "服务启动成功"
        
        # 等待服务就绪
        log_info "等待服务启动..."
        sleep 10
        
        # 运行健康检查
        if [[ -f "$PROJECT_DIR/scripts/health-check.sh" ]]; then
            log_info "运行健康检查..."
            "$PROJECT_DIR/scripts/health-check.sh" services || log_warn "部分服务可能未完全就绪"
        fi
        
        show_service_info
    else
        log_error "服务启动失败"
        return 1
    fi
}

# 测试并部署
test_and_deploy() {
    log_step "测试配置"
    echo ""
    
    # 验证环境变量
    log_info "验证环境变量..."
    if ! "$PROJECT_DIR/scripts/validate-env.sh"; then
        log_error "环境变量验证失败"
        return 1
    fi
    
    # 生成测试配置
    log_info "生成测试配置..."
    if ! "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate "$ENV_FILE"; then
        log_error "配置生成失败"
        return 1
    fi
    
    # 验证配置文件
    log_info "验证配置文件语法..."
    if ! python3 -c "import yaml; yaml.safe_load(open('$PROJECT_DIR/config/config.yaml'))"; then
        log_error "配置文件语法错误"
        return 1
    fi
    
    log_success "配置验证通过"
    echo ""
    
    read -p "配置验证成功，是否继续部署? (y/n): " -r continue_deploy
    if [[ "$continue_deploy" =~ ^[Yy]$ ]]; then
        deploy_services
    else
        show_manual_deployment_instructions
    fi
}

# 显示手动部署说明
show_manual_deployment_instructions() {
    log_step "手动部署说明"
    echo ""
    
    echo "配置已生成完成，您可以使用以下命令手动部署："
    echo ""
    
    # 基础部署
    echo "1. 基础部署:"
    echo "   docker compose up -d"
    echo ""
    
    # 安全部署
    if [[ "$ENABLE_SECURITY" == "true" ]]; then
        echo "2. 安全加固部署:"
        echo "   docker compose -f compose.yml -f security/compose.secure.yml up -d"
        echo ""
    fi
    
    # 完整部署
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        echo "3. 完整功能部署:"
        local compose_cmd="docker compose -f compose.yml"
        [[ "$ENABLE_SECURITY" == "true" ]] && compose_cmd+=" -f security/compose.secure.yml"
        compose_cmd+=" -f monitoring/compose.monitoring.yml up -d"
        echo "   $compose_cmd"
        echo ""
    fi
    
    echo "4. 验证部署:"
    echo "   ./scripts/health-check.sh"
    echo ""
    
    echo "5. 查看服务状态:"
    echo "   docker compose ps"
    echo ""
    
    echo "配置文件位置:"
    echo "  - 环境变量: $ENV_FILE"
    echo "  - Clash配置: $PROJECT_DIR/config/config.yaml"
    echo ""
}

# 显示服务信息
show_service_info() {
    echo ""
    log_success "部署完成！"
    echo ""
    
    echo -e "${CYAN}=== 服务访问信息 ===${NC}"
    echo ""
    
    echo "🔗 代理服务:"
    echo "   HTTP:  http://127.0.0.1:${CONFIG[CLASH_HTTP_PORT]}"
    echo "   SOCKS5: socks5://127.0.0.1:${CONFIG[CLASH_SOCKS_PORT]}"
    echo ""
    
    echo "🌐 Web界面:"
    echo "   配置文件: http://127.0.0.1:${CONFIG[NGINX_PORT]}/config.yaml"
    echo "   API: http://127.0.0.1:${CONFIG[NGINX_PORT]}/api/"
    
    if [[ "$ENABLE_SECURITY" == "true" ]]; then
        echo "   管理面板: http://127.0.0.1:${CONFIG[NGINX_PORT]}/dashboard/"
        echo "   用户名: ${CONFIG[NGINX_AUTH_USER]}"
        echo "   密码: ${CONFIG[NGINX_AUTH_PASS]}"
    fi
    echo ""
    
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        echo "📊 监控服务:"
        echo "   Grafana: http://127.0.0.1:3000 (admin/admin)"
        echo "   Prometheus: http://127.0.0.1:9090"
        echo ""
    fi
    
    echo "🔧 管理命令:"
    echo "   查看状态: docker compose ps"
    echo "   查看日志: docker compose logs -f"
    echo "   停止服务: docker compose down"
    echo "   健康检查: ./scripts/health-check.sh"
    echo ""
    
    echo "📖 更多信息请查看文档: docs/README.md"
}

# 主函数
main() {
    show_welcome
    check_requirements
    select_deployment_mode
    configure_basic_settings
    configure_proxy_servers
    configure_security
    configure_monitoring
    generate_env_file
    select_deployment_method
    
    echo ""
    log_success "安装向导完成！"
    
    if [[ -n "${backup_env:-}" ]]; then
        echo ""
        log_info "如需恢复原配置，请运行: mv $backup_env $ENV_FILE"
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi