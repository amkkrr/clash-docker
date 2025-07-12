#!/bin/bash

# 健康检查脚本 - 企业级服务健康监控
# 提供详细的健康状态检查和指标收集

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR="$PROJECT_DIR/test-suite/temp"

# 配置
CLASH_API_URL="http://localhost:19090"
NGINX_URL="http://localhost:18088"
CONFIG_FILE="$PROJECT_DIR/config/config.yaml"
HEALTH_LOG="$PROJECT_DIR/logs/health-check.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTH_LOG"
}

log_info() { log_with_timestamp "${BLUE}[INFO]${NC} $1"; }
log_success() { log_with_timestamp "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { log_with_timestamp "${RED}[ERROR]${NC} $1"; }
log_warn() { log_with_timestamp "${YELLOW}[WARN]${NC} $1"; }

# 健康检查结果
declare -A health_status
declare -A health_details
overall_health="healthy"

# 检查服务可达性
check_service_connectivity() {
    local service_name="$1"
    local url="$2"
    local timeout="${3:-5}"
    
    log_info "检查 $service_name 连通性: $url"
    
    if curl -sf --max-time "$timeout" "$url" >/dev/null 2>&1; then
        health_status["$service_name"]="healthy"
        health_details["$service_name"]="Service is responding normally"
        log_success "$service_name 服务连通正常"
        return 0
    else
        health_status["$service_name"]="unhealthy"
        health_details["$service_name"]="Service is not responding"
        log_error "$service_name 服务连通失败"
        overall_health="unhealthy"
        return 1
    fi
}

# 检查Clash API健康状态
check_clash_health() {
    log_info "检查 Clash API 健康状态"
    
    # 检查版本端点
    if ! check_service_connectivity "clash-api" "$CLASH_API_URL/version"; then
        return 1
    fi
    
    # 检查API响应内容
    local version_response
    if version_response=$(curl -sf "$CLASH_API_URL/version" 2>/dev/null); then
        if echo "$version_response" | jq -e '.version' >/dev/null 2>&1; then
            local version=$(echo "$version_response" | jq -r '.version')
            health_details["clash-api"]="Version: $version, API responding correctly"
            log_success "Clash API 版本检查通过: $version"
        else
            health_status["clash-api"]="degraded"
            health_details["clash-api"]="API responding but invalid JSON format"
            log_warn "Clash API 响应格式异常"
        fi
    fi
    
    # 检查代理状态
    local proxies_response
    if proxies_response=$(curl -sf "$CLASH_API_URL/proxies" 2>/dev/null); then
        local proxy_count=$(echo "$proxies_response" | jq '.proxies | length' 2>/dev/null || echo "0")
        health_details["clash-proxies"]="Active proxies: $proxy_count"
        log_info "检测到 $proxy_count 个代理节点"
        
        if [[ $proxy_count -eq 0 ]]; then
            log_warn "未检测到可用代理节点"
        fi
    else
        health_status["clash-proxies"]="unhealthy"
        health_details["clash-proxies"]="Unable to retrieve proxy information"
        log_error "无法获取代理信息"
        overall_health="degraded"
    fi
}

# 检查Nginx健康状态
check_nginx_health() {
    log_info "检查 Nginx 健康状态"
    
    # 检查健康端点
    if ! check_service_connectivity "nginx" "$NGINX_URL/health"; then
        return 1
    fi
    
    # 检查配置文件访问
    if curl -sf "$NGINX_URL/config.yaml" >/dev/null 2>&1; then
        health_status["nginx-config"]="healthy"
        health_details["nginx-config"]="Configuration file accessible via HTTP"
        log_success "配置文件HTTP访问正常"
    else
        health_status["nginx-config"]="unhealthy"
        health_details["nginx-config"]="Configuration file not accessible"
        log_error "配置文件HTTP访问失败"
        overall_health="degraded"
    fi
    
    # 检查API代理
    if curl -sf "$NGINX_URL/api/version" >/dev/null 2>&1; then
        health_status["nginx-proxy"]="healthy"
        health_details["nginx-proxy"]="API proxy functioning correctly"
        log_success "Nginx API代理正常"
    else
        health_status["nginx-proxy"]="unhealthy"
        health_details["nginx-proxy"]="API proxy not working"
        log_error "Nginx API代理失败"
        overall_health="degraded"
    fi
}

# 检查配置文件状态
check_config_file() {
    log_info "检查配置文件状态"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        health_status["config-file"]="missing"
        health_details["config-file"]="Configuration file does not exist"
        log_error "配置文件不存在: $CONFIG_FILE"
        overall_health="unhealthy"
        return 1
    fi
    
    # 检查文件大小
    local file_size=$(stat -f%z "$CONFIG_FILE" 2>/dev/null || stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "0")
    if [[ $file_size -lt 100 ]]; then
        health_status["config-file"]="invalid"
        health_details["config-file"]="Configuration file too small ($file_size bytes)"
        log_error "配置文件过小，可能损坏: $file_size bytes"
        overall_health="unhealthy"
        return 1
    fi
    
    # 检查YAML语法
    if python3 -c "
import yaml
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax valid')
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
" 2>/dev/null; then
        health_status["config-file"]="healthy"
        health_details["config-file"]="Valid YAML syntax, size: $file_size bytes"
        log_success "配置文件语法正确，大小: $file_size bytes"
    else
        health_status["config-file"]="invalid"
        health_details["config-file"]="Invalid YAML syntax"
        log_error "配置文件YAML语法错误"
        overall_health="unhealthy"
        return 1
    fi
    
    # 检查最后修改时间
    local mod_time=$(stat -f%m "$CONFIG_FILE" 2>/dev/null || stat -c%Y "$CONFIG_FILE" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - mod_time))
    
    if [[ $age -gt 86400 ]]; then
        log_warn "配置文件已超过24小时未更新 (${age}秒前)"
    else
        log_info "配置文件更新时间: $age 秒前"
    fi
}

# 检查Docker容器状态
check_docker_containers() {
    log_info "检查Docker容器状态"
    
    local containers=("clash-test" "clash-nginx-test" "clash-monitoring-test")
    
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
            local health=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
            
            if [[ "$status" == "running" ]]; then
                if [[ "$health" == "healthy" ]] || [[ "$health" == "none" ]]; then
                    health_status["container-$container"]="healthy"
                    health_details["container-$container"]="Container running, health: $health"
                    log_success "容器 $container 运行正常"
                else
                    health_status["container-$container"]="unhealthy"
                    health_details["container-$container"]="Container running but unhealthy: $health"
                    log_error "容器 $container 运行但不健康: $health"
                    overall_health="degraded"
                fi
            else
                health_status["container-$container"]="stopped"
                health_details["container-$container"]="Container not running: $status"
                log_error "容器 $container 未运行: $status"
                overall_health="unhealthy"
            fi
        else
            health_status["container-$container"]="missing"
            health_details["container-$container"]="Container not found"
            log_error "容器 $container 不存在"
            overall_health="unhealthy"
        fi
    done
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源状态"
    
    # 检查磁盘空间
    local disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        health_status["disk-space"]="critical"
        health_details["disk-space"]="Disk usage: ${disk_usage}%"
        log_error "磁盘空间不足: ${disk_usage}%"
        overall_health="unhealthy"
    elif [[ $disk_usage -gt 80 ]]; then
        health_status["disk-space"]="warning"
        health_details["disk-space"]="Disk usage: ${disk_usage}%"
        log_warn "磁盘空间紧张: ${disk_usage}%"
    else
        health_status["disk-space"]="healthy"
        health_details["disk-space"]="Disk usage: ${disk_usage}%"
        log_success "磁盘空间充足: ${disk_usage}%"
    fi
    
    # 检查内存使用
    if command -v free >/dev/null 2>&1; then
        local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
        health_details["memory"]="Memory usage: ${mem_usage}%"
        
        if (( $(echo "$mem_usage > 90" | bc -l) )); then
            health_status["memory"]="critical"
            log_error "内存使用率过高: ${mem_usage}%"
            overall_health="degraded"
        else
            health_status["memory"]="healthy"
            log_info "内存使用率: ${mem_usage}%"
        fi
    fi
}

# 生成健康检查报告
generate_health_report() {
    local report_file="$PROJECT_DIR/logs/health-report.json"
    local timestamp=$(date -u -Iseconds)
    
    log_info "生成健康检查报告: $report_file"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$timestamp",
    "overall_status": "$overall_health",
    "checks": {
EOF

    local first=true
    for check in "${!health_status[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> "$report_file"
        fi
        echo "        \"$check\": {" >> "$report_file"
        echo "            \"status\": \"${health_status[$check]}\"," >> "$report_file"
        echo "            \"details\": \"${health_details[$check]}\"" >> "$report_file"
        echo -n "        }" >> "$report_file"
        first=false
    done

    cat >> "$report_file" << EOF

    }
}
EOF
    
    log_success "健康检查报告已生成"
}

# 输出健康检查摘要
print_health_summary() {
    echo ""
    log_info "=== 健康检查摘要 ==="
    echo ""
    
    printf "%-25s %-15s %s\n" "检查项目" "状态" "详情"
    printf "%-25s %-15s %s\n" "--------" "----" "----"
    
    for check in "${!health_status[@]}"; do
        local status="${health_status[$check]}"
        local details="${health_details[$check]}"
        
        case "$status" in
            "healthy") status_display="${GREEN}HEALTHY${NC}" ;;
            "unhealthy") status_display="${RED}UNHEALTHY${NC}" ;;
            "degraded") status_display="${YELLOW}DEGRADED${NC}" ;;
            "warning") status_display="${YELLOW}WARNING${NC}" ;;
            "critical") status_display="${RED}CRITICAL${NC}" ;;
            *) status_display="$status" ;;
        esac
        
        printf "%-25s %-25s %s\n" "$check" "$status_display" "$details"
    done
    
    echo ""
    case "$overall_health" in
        "healthy") 
            log_success "🟢 系统整体健康状态: 良好"
            ;;
        "degraded")
            log_warn "🟡 系统整体健康状态: 降级"
            ;;
        "unhealthy")
            log_error "🔴 系统整体健康状态: 不健康"
            ;;
    esac
}

# 主函数
main() {
    local mode="${1:-full}"
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$HEALTH_LOG")" "$PROJECT_DIR/logs"
    
    log_info "开始健康检查 (模式: $mode)"
    
    case "$mode" in
        "full")
            check_clash_health
            check_nginx_health
            check_config_file
            check_docker_containers
            check_system_resources
            ;;
        "services")
            check_clash_health
            check_nginx_health
            ;;
        "config")
            check_config_file
            ;;
        "containers")
            check_docker_containers
            ;;
        "resources")
            check_system_resources
            ;;
        *)
            log_error "未知模式: $mode"
            echo "用法: $0 [full|services|config|containers|resources]"
            exit 1
            ;;
    esac
    
    generate_health_report
    print_health_summary
    
    # 根据整体健康状态设置退出码
    case "$overall_health" in
        "healthy") exit 0 ;;
        "degraded") exit 1 ;;
        "unhealthy") exit 2 ;;
        *) exit 3 ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi