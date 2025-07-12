#!/bin/bash

# 配置验证脚本 - 企业级环境变量验证器
# 功能：验证所有必需的环境变量是否存在且格式正确

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# 验证函数
validate_port() {
    local port="$1"
    local name="$2"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port $name: $port (must be 1-65535)"
        return 1
    fi
}

validate_ip() {
    local ip="$1"
    local name="$2"
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid IP $name: $ip"
        return 1
    fi
}

validate_cidr() {
    local cidr="$1"
    local name="$2"
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid CIDR $name: $cidr"
        return 1
    fi
}

validate_uuid() {
    local uuid="$1"
    local name="$2"
    if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        log_error "Invalid UUID $name: $uuid"
        return 1
    fi
}

validate_domain() {
    local domain="$1"
    local name="$2"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain $name: $domain"
        return 1
    fi
}

# 主验证逻辑
main() {
    local env_file="${1:-.env}"
    local validation_errors=0
    
    log_info "开始验证环境变量配置文件: $env_file"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        exit 1
    fi
    
    # 加载环境变量
    set -a
    source "$env_file"
    set +a
    
    log_info "验证基础Clash配置..."
    
    # 验证基础配置
    [[ -z "${CLASH_SECRET:-}" ]] && { log_error "CLASH_SECRET is required"; ((validation_errors++)); }
    [[ ${#CLASH_SECRET} -lt 8 ]] && { log_warn "CLASH_SECRET should be at least 8 characters"; }
    
    validate_port "${CLASH_HTTP_PORT:-}" "CLASH_HTTP_PORT" || ((validation_errors++))
    validate_port "${CLASH_SOCKS_PORT:-}" "CLASH_SOCKS_PORT" || ((validation_errors++))
    validate_port "${CLASH_CONTROL_PORT:-}" "CLASH_CONTROL_PORT" || ((validation_errors++))
    validate_port "${NGINX_PORT:-}" "NGINX_PORT" || ((validation_errors++))
    
    log_info "验证代理服务器配置..."
    
    # 验证代理服务器配置
    local required_domains=(
        "JP_HYSTERIA2_SERVER" "SJC_HYSTERIA2_SERVER" "SJC_LANDING_SS_SERVER"
        "JP_DIRECT_SERVER" "SJC_LANDING_HYSTERIA2_SERVER" "SJC_DIRECT_SERVER"
        "SJC_LANDING_DIRECT_SERVER" "SJC_RELAY_SERVER"
    )
    
    for domain_var in "${required_domains[@]}"; do
        local domain_value="${!domain_var:-}"
        [[ -z "$domain_value" ]] && { log_error "$domain_var is required"; ((validation_errors++)); continue; }
        validate_domain "$domain_value" "$domain_var" || ((validation_errors++))
    done
    
    # 验证UUID
    local required_uuids=("JP_DIRECT_UUID" "SJC_DIRECT_UUID" "SJC_LANDING_DIRECT_UUID")
    for uuid_var in "${required_uuids[@]}"; do
        local uuid_value="${!uuid_var:-}"
        [[ -z "$uuid_value" ]] && { log_error "$uuid_var is required"; ((validation_errors++)); continue; }
        validate_uuid "$uuid_value" "$uuid_var" || ((validation_errors++))
    done
    
    log_info "验证网络配置..."
    
    # 验证IP配置
    local ip_vars=(
        "SERVICE_IP_1" "SERVICE_IP_2" "REGION_IP_1"
        "INTERNAL_IP_1" "INTERNAL_IP_2" "INTERNAL_IP_3" "INTERNAL_IP_4" "INTERNAL_IP_5" "INTERNAL_IP_6"
        "HK_IP_1" "HK_IP_2" "HK_IP_3" "HK_IP_4" "HK_IP_5" "HK_IP_6"
        "HK_IP_7" "HK_IP_8" "HK_IP_9" "HK_IP_10" "HK_IP_11" "HK_IP_12"
        "HK_IP_RANGE_1" "HK_IP_RANGE_2"
    )
    
    for ip_var in "${ip_vars[@]}"; do
        local ip_value="${!ip_var:-}"
        [[ -z "$ip_value" ]] && { log_error "$ip_var is required"; ((validation_errors++)); continue; }
        validate_ip "$ip_value" "$ip_var" || ((validation_errors++))
    done
    
    # 验证CIDR配置
    local cidr_vars=("PRIVATE_IP_RANGE_1" "PRIVATE_IP_RANGE_2")
    for cidr_var in "${cidr_vars[@]}"; do
        local cidr_value="${!cidr_var:-}"
        [[ -z "$cidr_value" ]] && { log_error "$cidr_var is required"; ((validation_errors++)); continue; }
        validate_cidr "$cidr_value" "$cidr_var" || ((validation_errors++))
    done
    
    # 端口冲突检查
    log_info "检查端口冲突..."
    local ports=("$CLASH_HTTP_PORT" "$CLASH_SOCKS_PORT" "$CLASH_CONTROL_PORT" "$NGINX_PORT")
    local unique_ports=($(printf "%s\n" "${ports[@]}" | sort -u))
    
    if [[ ${#ports[@]} -ne ${#unique_ports[@]} ]]; then
        log_error "Port conflicts detected in configuration"
        ((validation_errors++))
    fi
    
    # 验证结果
    if [[ $validation_errors -eq 0 ]]; then
        log_success "所有环境变量验证通过！"
        return 0
    else
        log_error "发现 $validation_errors 个验证错误"
        return 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi