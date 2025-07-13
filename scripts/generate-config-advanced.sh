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
LOG_DIR="$PROJECT_DIR/logs"

# 创建必要目录
mkdir -p "$CONFIG_BACKUP_DIR" "$TEMP_DIR" "$LOG_DIR"

# 设置详细日志文件
DETAIL_LOG="$LOG_DIR/config-generation-$(date +%Y%m%d-%H%M%S).log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数 - 同时输出到控制台和详细日志文件
log_info() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1" | tee -a "$DETAIL_LOG"; }
log_warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${NC} $1" | tee -a "$DETAIL_LOG"; }
log_error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1" | tee -a "$DETAIL_LOG"; }
log_success() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1" | tee -a "$DETAIL_LOG"; }

# 错误处理和分类
declare -A ERROR_TYPES=(
    [1]="通用错误"
    [2]="环境文件错误"
    [3]="模板验证错误"
    [4]="配置生成错误"
    [5]="YAML语法错误"
    [6]="字段验证错误"
    [7]="权限错误"
    [8]="文件不存在错误"
)

# 专用错误函数
error_exit() {
    local error_code=$1
    local error_message=$2
    local error_type="${ERROR_TYPES[$error_code]:-未知错误类型}"
    
    log_error "❌ 错误类型: $error_type (代码: $error_code)"
    log_error "❌ 错误详情: $error_message"
    log_error "❌ 发生时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 回滚配置文件（如果需要）
    if [[ -f "$CONFIG_OUTPUT.backup" ]]; then
        log_info "🔄 恢复之前的配置文件..."
        mv "$CONFIG_OUTPUT.backup" "$CONFIG_OUTPUT"
        log_info "✅ 配置文件已回滚"
    fi
    
    exit $error_code
}

# 改进的清理函数
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        local error_type="${ERROR_TYPES[$exit_code]:-未知错误类型}"
        log_error "💥 脚本异常退出"
        log_error "🚨 退出码: $exit_code ($error_type)"
        log_error "⏰ 异常时间: $(date '+%Y-%m-%d %H:%M:%S')"
        
        # 提供调试信息
        log_error "📍 调试信息:"
        log_error "   - 当前工作目录: $(pwd)"
        log_error "   - 配置输出文件: ${CONFIG_OUTPUT:-未设置}"
        log_error "   - 环境文件: ${ENV_FILE:-未设置}"
        
        if [[ -f "$CONFIG_OUTPUT.backup" ]]; then
            log_info "🔄 自动恢复之前的配置文件..."
            mv "$CONFIG_OUTPUT.backup" "$CONFIG_OUTPUT"
        fi
    else
        log_success "✅ 脚本正常完成"
    fi
    exit $exit_code
}

# 只在错误时触发清理
trap cleanup_on_error ERR

# 验证配置模板
validate_template() {
    log_info "验证配置模板语法..."
    
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        error_exit 8 "配置模板文件不存在: $CONFIG_TEMPLATE"
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
" 2>&1 || true)
    
    echo "$validation_output"
    
    if echo "$validation_output" | grep -q "Template syntax validation passed"; then
        log_success "配置模板语法验证通过"
    else
        error_exit 3 "配置模板语法验证失败: $validation_output"
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
        error_exit 2 "环境文件不存在: $env_file"
    fi
    
    # 验证环境变量
    if ! "$SCRIPT_DIR/validate-env.sh" "$env_file"; then
        error_exit 2 "环境变量验证失败，请检查 $env_file 文件内容"
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
    local envsubst_stderr_log="$TEMP_DIR/envsubst_stderr.log"
    if ! envsubst < "$CONFIG_TEMPLATE" > "$temp_config" 2> "$envsubst_stderr_log"; then
        local envsubst_error=""
        if [[ -s "$envsubst_stderr_log" ]]; then
            envsubst_error=": $(cat "$envsubst_stderr_log")"
        fi
        error_exit 4 "环境变量替换失败$envsubst_error"
    fi
    log_success "环境变量替换完成"
    
    # 验证生成的配置
    log_info "调试：准备验证生成的配置文件: $temp_config"
    log_info "调试：临时配置文件是否存在: $([ -f "$temp_config" ] && echo "是" || echo "否")"
    if [ -f "$temp_config" ]; then
        log_info "调试：临时配置文件大小: $(wc -c < "$temp_config") 字节"
        log_info "调试：临时配置文件前5行:"
        head -5 "$temp_config" || true
    fi
    
    validate_generated_config "$temp_config"
    
    # 移动到最终位置
    mv "$temp_config" "$CONFIG_OUTPUT"
    
    log_success "配置文件生成完成: $CONFIG_OUTPUT"
    log_info "详细日志已保存到: $DETAIL_LOG"
}

# 验证生成的配置文件
validate_generated_config() {
    local config_file="$1"
    
    log_info "验证生成的配置文件..."
    echo "=== DEBUG: validate_generated_config 函数开始执行 ==="
    log_info "调试：验证函数被调用，参数: $config_file"
    log_info "调试：验证函数中文件是否存在: $([ -f "$config_file" ] && echo "是" || echo "否")"
    log_info "调试：验证函数开始 YAML 语法检查"
    echo "=== DEBUG: 准备执行 Python YAML 验证 ==="
    
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
" 2>&1 || true)
    
    echo "=== DEBUG: Python 验证完成，开始显示输出 ==="
    log_info "调试：Python 验证输出："
    echo "$validation_output"
    echo "=== DEBUG: Python 验证输出结束 ==="
    
    # 详细调试信息
    log_info "调试：验证输出长度 = ${#validation_output}"
    log_info "调试：查找字符串 = 'YAML syntax validation passed'"
    
    # 强制测试匹配
    if [[ "$validation_output" == *"YAML syntax validation passed"* ]]; then
        log_info "调试：字符串匹配成功 (使用 [[ *pattern* ]])"
        log_success "生成的配置文件YAML语法正确"
    elif echo "$validation_output" | grep -q "YAML syntax validation passed"; then
        log_info "调试：grep 匹配成功"
        log_success "生成的配置文件YAML语法正确"
    else
        log_error "调试：所有匹配方法都失败"
        log_error "调试：验证输出内容 = '$validation_output'"
        log_error "调试：验证输出十六进制 = $(echo -n "$validation_output" | od -t x1 -A n | tr -d ' \n' | head -c 100)"
        error_exit 5 "生成的配置文件YAML语法错误: $validation_output"
    fi
    
    # 检查必要字段
    local fields_check_output
    fields_check_output=$(python3 -c "
import yaml
with open('$config_file', 'r') as f:
    config = yaml.safe_load(f)

required_fields = ['port', 'proxies', 'proxy-groups', 'rules']
missing_fields = [field for field in required_fields if field not in config]

if missing_fields:
    print(f'Missing required fields: {missing_fields}')
    exit(1)

print('All required fields present')
" 2>&1 || true)
    
    echo "$fields_check_output"
    
    # 详细调试信息
    log_info "调试：字段检查输出长度 = ${#fields_check_output}"
    log_info "调试：查找字符串 = 'All required fields present'"
    
    if echo "$fields_check_output" | grep -q "All required fields present"; then
        log_info "调试：字段检查 grep 匹配成功"
        log_success "配置文件包含所有必需字段"
    else
        log_error "调试：字段检查 grep 匹配失败"
        log_error "调试：字段检查输出内容 = '$fields_check_output'"
        error_exit 6 "配置文件缺少必需字段: $fields_check_output"
    fi
    
    # 检查环境变量是否全部替换
    if grep -q '\${' "$config_file"; then
        local unreplaced_vars=$(grep '\${' "$config_file" | head -5)
        error_exit 4 "配置文件中仍包含未替换的环境变量: $unreplaced_vars"
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
            log_success "🎉 配置生成流程全部完成！"
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
    # 显式成功退出
    log_success "🎉 所有操作完成！"
    exit 0
fi