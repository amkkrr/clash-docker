#!/bin/bash

# 高级配置生成脚本 - 企业级配置管理系统
# 功能：生成、验证、备份和回滚Clash配置文件

set -euo pipefail

# 配置常量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TEMPLATE="$PROJECT_DIR/config/clash-template.yaml"
CONFIG_OUTPUT="$PROJECT_DIR/config/config.yaml"
CONFIG_BACKUP_DIR="$PROJECT_DIR/config/backups"
TEMP_DIR="$PROJECT_DIR/test-suite/temp"

# 创建必要目录
mkdir -p "$CONFIG_BACKUP_DIR" "$TEMP_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1" | tee -a "$TEMP_DIR/config-generation.log"; }
log_warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${NC} $1" | tee -a "$TEMP_DIR/config-generation.log"; }
log_error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1" | tee -a "$TEMP_DIR/config-generation.log"; }
log_success() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEMP_DIR/config-generation.log"; }

# 错误处理
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "配置生成失败，退出码: $exit_code"
        if [[ -f "$CONFIG_OUTPUT.backup" ]]; then
            log_info "恢复之前的配置文件..."
            mv "$CONFIG_OUTPUT.backup" "$CONFIG_OUTPUT"
        fi
    fi
    exit $exit_code
}

trap cleanup_on_error EXIT

# 验证配置模板
validate_template() {
    log_info "验证配置模板语法..."
    
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        log_error "配置模板文件不存在: $CONFIG_TEMPLATE"
        return 1
    fi
    
    # 检查模板语法
    local validation_output
    validation_output=$(python3 -c "
import yaml
import sys
import os
try:
    template_path = '$CONFIG_TEMPLATE'
    if not os.path.exists(template_path):
        print(f'Template file not found: {template_path}')
        sys.exit(1)
    with open(template_path, 'r') as f:
        content = f.read()
    # 简单检查环境变量语法
    if '\${' in content and '}' in content:
        print('Template contains environment variables - OK')
    else:
        print('Warning: No environment variables found in template')
    print('Template syntax validation passed')
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'Template validation error: {e}')
    sys.exit(1)
" 2>&1)
    
    echo "$validation_output"
    
    if echo "$validation_output" | grep -q "Template syntax validation passed"; then
        log_success "配置模板语法验证通过"
    else
        log_error "配置模板语法验证失败"
        return 1
    fi
}

# 备份现有配置
backup_existing_config() {
    if [[ -f "$CONFIG_OUTPUT" ]]; then
        local backup_file="$CONFIG_BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).yaml"
        cp "$CONFIG_OUTPUT" "$backup_file"
        cp "$CONFIG_OUTPUT" "$CONFIG_OUTPUT.backup"
        log_info "已备份现有配置到: $backup_file"
    fi
}

# 生成配置文件
generate_config() {
    local env_file="${1:-.env}"
    
    log_info "开始生成Clash配置文件..."
    log_info "使用环境文件: $env_file"
    
    # 验证环境文件
    if [[ ! -f "$env_file" ]]; then
        log_error "环境文件不存在: $env_file"
        return 1
    fi
    
    # 验证环境变量
    if ! "$SCRIPT_DIR/validate-env.sh" "$env_file"; then
        log_error "环境变量验证失败"
        return 1
    fi
    
    # 加载环境变量
    set -a
    source "$env_file"
    set +a
    
    # 备份现有配置
    backup_existing_config
    
    # 验证模板
    validate_template
    
    # 生成临时配置文件
    local temp_config="$TEMP_DIR/config-temp-$(date +%s).yaml"
    
    log_info "替换环境变量..."
    if envsubst < "$CONFIG_TEMPLATE" > "$temp_config"; then
        log_success "环境变量替换完成"
    else
        log_error "环境变量替换失败"
        return 1
    fi
    
    # 验证生成的配置
    validate_generated_config "$temp_config"
    
    # 移动到最终位置
    mv "$temp_config" "$CONFIG_OUTPUT"
    
    log_success "配置文件生成完成: $CONFIG_OUTPUT"
}

# 验证生成的配置文件
validate_generated_config() {
    local config_file="$1"
    
    log_info "验证生成的配置文件..."
    
    # YAML语法检查
    local validation_output
    validation_output=$(python3 -c "
import yaml
import sys
import os
try:
    config_path = '$config_file'
    if not os.path.exists(config_path):
        print(f'Config file not found: {config_path}')
        sys.exit(1)
    with open(config_path, 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax validation passed')
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'Config validation error: {e}')
    sys.exit(1)
" 2>&1)
    
    echo "$validation_output"
    
    if echo "$validation_output" | grep -q "YAML syntax validation passed"; then
        log_success "生成的配置文件YAML语法正确"
    else
        log_error "生成的配置文件YAML语法错误"
        return 1
    fi
    
    # 检查必要字段
    if ! python3 -c "
import yaml
with open('$config_file', 'r') as f:
    config = yaml.safe_load(f)

required_fields = ['port', 'proxies', 'proxy-groups', 'rules']
missing_fields = [field for field in required_fields if field not in config]

if missing_fields:
    print(f'Missing required fields: {missing_fields}')
    exit(1)

print('All required fields present')
" 2>/dev/null; then
        log_success "配置文件包含所有必需字段"
    else
        log_error "配置文件缺少必需字段"
        return 1
    fi
    
    # 检查环境变量是否全部替换
    if grep -q '\${' "$config_file"; then
        log_warn "配置文件中仍包含未替换的环境变量:"
        grep '\${' "$config_file" || true
        return 1
    else
        log_success "所有环境变量已正确替换"
    fi
}

# 配置文件健康检查
health_check() {
    log_info "执行配置文件健康检查..."
    
    if [[ ! -f "$CONFIG_OUTPUT" ]]; then
        log_error "配置文件不存在: $CONFIG_OUTPUT"
        return 1
    fi
    
    # 文件大小检查
    local file_size=$(stat -f%z "$CONFIG_OUTPUT" 2>/dev/null || stat -c%s "$CONFIG_OUTPUT" 2>/dev/null || echo "0")
    if [[ $file_size -lt 1000 ]]; then
        log_warn "配置文件似乎太小 ($file_size bytes)，可能不完整"
    fi
    
    # 最后修改时间
    local mod_time=$(stat -f%m "$CONFIG_OUTPUT" 2>/dev/null || stat -c%Y "$CONFIG_OUTPUT" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - mod_time))
    
    if [[ $age -gt 3600 ]]; then
        log_warn "配置文件已超过1小时未更新"
    fi
    
    log_success "配置文件健康检查完成"
}

# 回滚配置
rollback_config() {
    log_info "开始回滚配置..."
    
    if [[ -f "$CONFIG_OUTPUT.backup" ]]; then
        mv "$CONFIG_OUTPUT.backup" "$CONFIG_OUTPUT"
        log_success "配置已回滚到之前版本"
    else
        local latest_backup=$(ls -t "$CONFIG_BACKUP_DIR"/config-*.yaml 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" "$CONFIG_OUTPUT"
            log_success "配置已回滚到: $latest_backup"
        else
            log_error "没有找到可回滚的备份配置"
            return 1
        fi
    fi
}

# 清理临时文件
cleanup_temp_files() {
    log_info "清理临时文件..."
    find "$TEMP_DIR" -name "config-temp-*.yaml" -mtime +1 -delete 2>/dev/null || true
    log_success "临时文件清理完成"
}

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $0 [选项] [环境文件]

选项:
    generate [env_file]    生成配置文件 (默认: .env)
    validate [env_file]    仅验证环境变量
    health-check          检查配置文件健康状态
    rollback             回滚到之前的配置
    cleanup              清理临时文件
    --help               显示此帮助信息

示例:
    $0 generate .env.test
    $0 validate .env.prod
    $0 health-check
    $0 rollback

EOF
}

# 主函数
main() {
    local command="${1:-generate}"
    local env_file="${2:-.env}"
    
    case "$command" in
        "generate")
            generate_config "$env_file"
            health_check
            cleanup_temp_files
            ;;
        "validate")
            "$SCRIPT_DIR/validate-env.sh" "$env_file"
            ;;
        "health-check")
            health_check
            ;;
        "rollback")
            rollback_config
            ;;
        "cleanup")
            cleanup_temp_files
            ;;
        "--help"|"-h")
            show_usage
            ;;
        *)
            log_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi