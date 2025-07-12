#!/bin/bash

# Clash Docker 管理工具
# 提供服务管理、监控、维护等功能的统一入口

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

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Clash Docker 管理工具${NC}"
    echo ""
    echo "用法: $0 <命令> [选项]"
    echo ""
    echo "可用命令:"
    echo ""
    echo -e "${YELLOW}服务管理:${NC}"
    echo "  start [mode]     - 启动服务 (basic|security|monitoring|all)"
    echo "  stop             - 停止服务"
    echo "  restart [mode]   - 重启服务"
    echo "  status           - 查看服务状态"
    echo "  logs [service]   - 查看日志"
    echo ""
    echo -e "${YELLOW}配置管理:${NC}"
    echo "  config generate  - 生成配置文件"
    echo "  config validate  - 验证配置"
    echo "  config backup    - 备份配置"
    echo "  config restore   - 恢复配置"
    echo ""
    echo -e "${YELLOW}监控和检查:${NC}"
    echo "  health [type]    - 健康检查 (full|services|config|containers)"
    echo "  monitor          - 实时监控"
    echo "  metrics          - 查看指标"
    echo ""
    echo -e "${YELLOW}安全管理:${NC}"
    echo "  security scan    - 安全扫描"
    echo "  security update  - 更新安全配置"
    echo "  security report  - 生成安全报告"
    echo ""
    echo -e "${YELLOW}测试和质量:${NC}"
    echo "  test [type]      - 运行测试 (unit|integration|e2e|all)"
    echo "  benchmark        - 性能基准测试"
    echo "  lint             - 代码检查"
    echo ""
    echo -e "${YELLOW}维护工具:${NC}"
    echo "  cleanup          - 清理临时文件"
    echo "  update           - 更新镜像"
    echo "  backup           - 完整备份"
    echo "  export           - 导出配置"
    echo ""
    echo -e "${YELLOW}其他:${NC}"
    echo "  wizard           - 运行安装向导"
    echo "  version          - 显示版本信息"
    echo "  help             - 显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 start security    # 启动安全模式"
    echo "  $0 health full       # 完整健康检查"
    echo "  $0 logs clash        # 查看Clash日志"
    echo "  $0 test integration  # 运行集成测试"
}

# 服务管理
service_start() {
    local mode="${1:-basic}"
    log_info "启动服务 (模式: $mode)"
    
    local compose_files=("-f" "$PROJECT_DIR/compose.yml")
    
    case "$mode" in
        "security")
            compose_files+=("-f" "$PROJECT_DIR/security/compose.secure.yml")
            ;;
        "monitoring")
            compose_files+=("-f" "$PROJECT_DIR/monitoring/compose.monitoring.yml")
            ;;
        "all")
            compose_files+=("-f" "$PROJECT_DIR/security/compose.secure.yml")
            compose_files+=("-f" "$PROJECT_DIR/monitoring/compose.monitoring.yml")
            ;;
        "basic")
            # 仅使用基础配置
            ;;
        *)
            log_error "未知模式: $mode"
            echo "支持的模式: basic, security, monitoring, all"
            return 1
            ;;
    esac
    
    # 生成配置
    if [[ -f "$PROJECT_DIR/scripts/generate-config-advanced.sh" ]]; then
        log_info "生成配置文件..."
        "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate
    fi
    
    # 启动服务
    cd "$PROJECT_DIR"
    if docker compose "${compose_files[@]}" up -d; then
        log_success "服务启动成功"
        
        # 等待服务就绪
        sleep 5
        service_status
    else
        log_error "服务启动失败"
        return 1
    fi
}

service_stop() {
    log_info "停止服务"
    cd "$PROJECT_DIR"
    
    # 停止所有可能的配置
    docker compose down 2>/dev/null || true
    docker compose -f security/compose.secure.yml down 2>/dev/null || true
    docker compose -f monitoring/compose.monitoring.yml down 2>/dev/null || true
    
    log_success "服务已停止"
}

service_restart() {
    local mode="${1:-basic}"
    log_info "重启服务"
    
    service_stop
    sleep 3
    service_start "$mode"
}

service_status() {
    log_info "服务状态"
    cd "$PROJECT_DIR"
    
    echo ""
    echo -e "${CYAN}=== Docker Compose 服务 ===${NC}"
    docker compose ps
    
    echo ""
    echo -e "${CYAN}=== 端口监听状态 ===${NC}"
    local ports=("7890" "7891" "9090" "8088" "3000" "9091")
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✓${NC} 端口 $port 正在监听"
        else
            echo -e "${RED}✗${NC} 端口 $port 未监听"
        fi
    done
    
    echo ""
    echo -e "${CYAN}=== 容器健康状态 ===${NC}"
    docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}" | grep -E "(clash|nginx)" || echo "未找到相关容器"
}

service_logs() {
    local service="${1:-}"
    cd "$PROJECT_DIR"
    
    if [[ -n "$service" ]]; then
        log_info "查看 $service 服务日志"
        docker compose logs -f "$service"
    else
        log_info "查看所有服务日志"
        docker compose logs -f
    fi
}

# 配置管理
config_generate() {
    log_info "生成配置文件"
    
    if [[ -f "$PROJECT_DIR/scripts/generate-config-advanced.sh" ]]; then
        "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate
        log_success "配置文件已生成"
    else
        log_error "配置生成脚本不存在"
        return 1
    fi
}

config_validate() {
    log_info "验证配置"
    
    # 验证环境变量
    if [[ -f "$PROJECT_DIR/scripts/validate-env.sh" ]]; then
        "$PROJECT_DIR/scripts/validate-env.sh"
    fi
    
    # 验证YAML语法
    local config_file="$PROJECT_DIR/config/config.yaml"
    if [[ -f "$config_file" ]]; then
        if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
            log_success "配置文件语法正确"
        else
            log_error "配置文件语法错误"
            return 1
        fi
    else
        log_error "配置文件不存在: $config_file"
        return 1
    fi
}

config_backup() {
    log_info "备份配置"
    
    local backup_dir="$PROJECT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份关键文件
    local files_to_backup=(
        ".env"
        "config/config.yaml" 
        "docker-compose.yml"
        "compose.yml"
    )
    
    for file in "${files_to_backup[@]}"; do
        local source="$PROJECT_DIR/$file"
        if [[ -f "$source" ]]; then
            cp "$source" "$backup_dir/"
            log_info "已备份: $file"
        fi
    done
    
    log_success "配置已备份到: $backup_dir"
}

config_restore() {
    log_info "恢复配置"
    
    local backup_dir="$PROJECT_DIR/backups"
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    echo "可用的备份:"
    ls -1t "$backup_dir" | head -10
    echo ""
    
    read -p "请输入要恢复的备份目录名: " -r backup_name
    local restore_from="$backup_dir/$backup_name"
    
    if [[ ! -d "$restore_from" ]]; then
        log_error "备份不存在: $restore_from"
        return 1
    fi
    
    # 恢复文件
    for file in "$restore_from"/*; do
        local filename=$(basename "$file")
        local target="$PROJECT_DIR/$filename"
        
        if [[ -f "$target" ]]; then
            cp "$target" "$target.backup.$(date +%s)"
        fi
        
        cp "$file" "$target"
        log_info "已恢复: $filename"
    done
    
    log_success "配置恢复完成"
}

# 监控和检查
health_check() {
    local type="${1:-full}"
    
    if [[ -f "$PROJECT_DIR/scripts/health-check.sh" ]]; then
        log_info "运行健康检查 (类型: $type)"
        "$PROJECT_DIR/scripts/health-check.sh" "$type"
    else
        log_error "健康检查脚本不存在"
        return 1
    fi
}

monitor_realtime() {
    log_info "实时监控 (按 Ctrl+C 退出)"
    
    while true; do
        clear
        echo -e "${CYAN}=== Clash Docker 实时监控 ===${NC}"
        echo -e "${YELLOW}时间: $(date)${NC}"
        echo ""
        
        # 服务状态
        echo -e "${CYAN}服务状态:${NC}"
        docker compose ps --format "table {{.Name}}\\t{{.Status}}" 2>/dev/null || echo "无法获取服务状态"
        echo ""
        
        # 资源使用
        echo -e "${CYAN}资源使用:${NC}"
        docker stats --no-stream --format "table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}" 2>/dev/null | grep -E "(clash|nginx)" || echo "无法获取资源信息"
        echo ""
        
        # 网络连接
        echo -e "${CYAN}网络连接:${NC}"
        netstat -tlnp 2>/dev/null | grep -E ":(7890|7891|9090|8088)" | awk '{print $1 "\\t" $4}' || echo "无法获取网络信息"
        
        sleep 5
    done
}

show_metrics() {
    log_info "显示系统指标"
    
    echo ""
    echo -e "${CYAN}=== 系统资源 ===${NC}"
    
    # CPU使用率
    if command -v top >/dev/null 2>&1; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo "CPU使用率: ${cpu_usage}%"
    fi
    
    # 内存使用率
    if command -v free >/dev/null 2>&1; then
        free -h
    fi
    
    # 磁盘使用率
    echo ""
    echo -e "${CYAN}=== 磁盘使用 ===${NC}"
    df -h "$PROJECT_DIR" | tail -1
    
    # Docker资源
    echo ""
    echo -e "${CYAN}=== Docker 资源 ===${NC}"
    docker system df
    
    # 容器统计
    echo ""
    echo -e "${CYAN}=== 容器状态 ===${NC}"
    docker stats --no-stream 2>/dev/null | grep -E "(clash|nginx)" || echo "未找到相关容器"
}

# 安全管理
security_scan() {
    log_info "运行安全扫描"
    
    if [[ -f "$PROJECT_DIR/security/docker-security-scan.sh" ]]; then
        "$PROJECT_DIR/security/docker-security-scan.sh"
    else
        log_error "安全扫描脚本不存在"
        return 1
    fi
}

security_update() {
    log_info "更新安全配置"
    
    # 更新密码文件权限
    local htpasswd_file="$PROJECT_DIR/security/htpasswd"
    if [[ -f "$htpasswd_file" ]]; then
        chmod 600 "$htpasswd_file"
        log_info "已更新密码文件权限"
    fi
    
    # 检查配置文件权限
    local config_files=("$PROJECT_DIR/.env" "$PROJECT_DIR/config/config.yaml")
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            chmod 600 "$file"
            log_info "已更新配置文件权限: $(basename "$file")"
        fi
    done
    
    log_success "安全配置更新完成"
}

security_report() {
    log_info "生成安全报告"
    
    local report_file="$PROJECT_DIR/logs/security-report-$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "Clash Docker 安全报告"
        echo "生成时间: $(date)"
        echo "========================"
        echo ""
        
        echo "文件权限检查:"
        ls -la "$PROJECT_DIR/.env" 2>/dev/null || echo ".env 文件不存在"
        ls -la "$PROJECT_DIR/config/config.yaml" 2>/dev/null || echo "config.yaml 文件不存在"
        echo ""
        
        echo "容器安全检查:"
        docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}" | grep -E "(clash|nginx)" || echo "未找到相关容器"
        echo ""
        
        echo "端口监听检查:"
        netstat -tlnp 2>/dev/null | grep -E ":(7890|7891|9090|8088)" || echo "未发现监听端口"
        
    } > "$report_file"
    
    log_success "安全报告已生成: $report_file"
}

# 测试和质量
run_tests() {
    local type="${1:-all}"
    log_info "运行测试 (类型: $type)"
    
    case "$type" in
        "unit")
            if [[ -f "$PROJECT_DIR/test-suite/unit/run-tests.sh" ]]; then
                "$PROJECT_DIR/test-suite/unit/run-tests.sh"
            else
                log_error "单元测试脚本不存在"
                return 1
            fi
            ;;
        "integration")
            if [[ -f "$PROJECT_DIR/test-suite/integration/run-tests.sh" ]]; then
                "$PROJECT_DIR/test-suite/integration/run-tests.sh"
            else
                log_error "集成测试脚本不存在"
                return 1
            fi
            ;;
        "e2e")
            if [[ -f "$PROJECT_DIR/test-suite/e2e/run-tests.sh" ]]; then
                "$PROJECT_DIR/test-suite/e2e/run-tests.sh"
            else
                log_error "端到端测试脚本不存在"
                return 1
            fi
            ;;
        "all")
            if [[ -f "$PROJECT_DIR/test-suite/run-all-tests.sh" ]]; then
                "$PROJECT_DIR/test-suite/run-all-tests.sh"
            else
                log_error "测试套件脚本不存在"
                return 1
            fi
            ;;
        *)
            log_error "未知测试类型: $type"
            echo "支持的类型: unit, integration, e2e, all"
            return 1
            ;;
    esac
}

run_benchmark() {
    log_info "运行性能基准测试"
    
    if [[ -f "$PROJECT_DIR/test-suite/performance/benchmark.sh" ]]; then
        "$PROJECT_DIR/test-suite/performance/benchmark.sh"
    else
        log_error "基准测试脚本不存在"
        return 1
    fi
}

# 维护工具
cleanup() {
    log_info "清理临时文件"
    
    # 清理临时目录
    local temp_dirs=(
        "$PROJECT_DIR/test-suite/temp"
        "$PROJECT_DIR/logs/temp"
        "$PROJECT_DIR/.cache"
    )
    
    for dir in "${temp_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            log_info "已清理: $dir"
        fi
    done
    
    # 清理Docker临时文件
    docker system prune -f >/dev/null 2>&1 || true
    
    # 清理旧日志文件 (保留最近7天)
    find "$PROJECT_DIR/logs" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    
    log_success "清理完成"
}

update_images() {
    log_info "更新Docker镜像"
    
    local images=("dreamacro/clash:latest" "nginx:alpine" "alpine:latest")
    
    for image in "${images[@]}"; do
        log_info "更新镜像: $image"
        docker pull "$image"
    done
    
    log_success "镜像更新完成"
}

full_backup() {
    log_info "创建完整备份"
    
    local backup_file="$PROJECT_DIR/backups/full-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$(dirname "$backup_file")"
    
    # 创建备份
    local backup_items=(
        "config/"
        "security/"
        "scripts/"
        ".env"
        "compose.yml"
        "logs/"
    )
    
    cd "$PROJECT_DIR"
    tar -czf "$backup_file" "${backup_items[@]}" 2>/dev/null || true
    
    log_success "完整备份已创建: $backup_file"
}

export_config() {
    log_info "导出配置"
    
    local export_file="$PROJECT_DIR/exports/config-export-$(date +%Y%m%d_%H%M%S).zip"
    mkdir -p "$(dirname "$export_file")"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 复制配置文件 (去除敏感信息)
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        grep -v -E "(PASSWORD|SECRET|KEY)" "$PROJECT_DIR/.env" > "$temp_dir/.env.template" || true
    fi
    
    if [[ -f "$PROJECT_DIR/config/config.yaml" ]]; then
        cp "$PROJECT_DIR/config/config.yaml" "$temp_dir/"
    fi
    
    # 复制文档
    cp -r "$PROJECT_DIR/docs" "$temp_dir/" 2>/dev/null || true
    
    # 创建导出包
    cd "$temp_dir"
    zip -r "$export_file" . >/dev/null 2>&1
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    log_success "配置已导出: $export_file"
}

# 其他功能
run_wizard() {
    if [[ -f "$PROJECT_DIR/tools/setup-wizard.sh" ]]; then
        "$PROJECT_DIR/tools/setup-wizard.sh"
    else
        log_error "安装向导不存在"
        return 1
    fi
}

show_version() {
    echo -e "${CYAN}Clash Docker 管理工具${NC}"
    echo "版本: 1.0.0"
    echo "构建日期: $(date -r "$0" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '未知')"
    echo ""
    
    # 显示相关版本信息
    echo "依赖版本:"
    docker --version 2>/dev/null || echo "Docker: 未安装"
    docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "Docker Compose: 未安装"
    
    # 检查项目文件
    echo ""
    echo "项目状态:"
    [[ -f "$PROJECT_DIR/.env" ]] && echo "✓ 环境配置存在" || echo "✗ 环境配置缺失"
    [[ -f "$PROJECT_DIR/config/config.yaml" ]] && echo "✓ Clash配置存在" || echo "✗ Clash配置缺失"
    [[ -f "$PROJECT_DIR/compose.yml" ]] && echo "✓ Docker Compose配置存在" || echo "✗ Docker Compose配置缺失"
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        return 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        # 服务管理
        "start") service_start "$@" ;;
        "stop") service_stop ;;
        "restart") service_restart "$@" ;;
        "status") service_status ;;
        "logs") service_logs "$@" ;;
        
        # 配置管理
        "config")
            local subcommand="${1:-}"
            case "$subcommand" in
                "generate") config_generate ;;
                "validate") config_validate ;;
                "backup") config_backup ;;
                "restore") config_restore ;;
                *) log_error "未知配置命令: $subcommand" ;;
            esac
            ;;
        
        # 监控和检查
        "health") health_check "$@" ;;
        "monitor") monitor_realtime ;;
        "metrics") show_metrics ;;
        
        # 安全管理
        "security")
            local subcommand="${1:-}"
            case "$subcommand" in
                "scan") security_scan ;;
                "update") security_update ;;
                "report") security_report ;;
                *) log_error "未知安全命令: $subcommand" ;;
            esac
            ;;
        
        # 测试和质量
        "test") run_tests "$@" ;;
        "benchmark") run_benchmark ;;
        
        # 维护工具
        "cleanup") cleanup ;;
        "update") update_images ;;
        "backup") full_backup ;;
        "export") export_config ;;
        
        # 其他
        "wizard") run_wizard ;;
        "version") show_version ;;
        "help") show_help ;;
        
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi