#!/bin/bash

# Clash配置调试脚本
# 提供详细的独立日志和分析功能

set -euo pipefail

# 配置常量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DEBUG_LOG="$LOG_DIR/debug-$(date +%Y%m%d-%H%M%S).log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 增强的日志函数 - 同时输出到控制台和文件
log_debug() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1"
    echo -e "${CYAN}$msg${NC}" | tee -a "$DEBUG_LOG"
}
log_info() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
    echo -e "${BLUE}$msg${NC}" | tee -a "$DEBUG_LOG"
}
log_warn() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
    echo -e "${YELLOW}$msg${NC}" | tee -a "$DEBUG_LOG"
}
log_error() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1"
    echo -e "${RED}$msg${NC}" | tee -a "$DEBUG_LOG"
}
log_success() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}" | tee -a "$DEBUG_LOG"
}

# 保存原始数据到文件
save_data() {
    local name="$1"
    local content="$2"
    local file="$LOG_DIR/${name}-$(date +%H%M%S).log"
    echo "$content" > "$file"
    log_debug "数据已保存到: $file"
    echo "$file"
}

# 分析YAML内容
analyze_yaml() {
    local yaml_file="$1"
    log_info "分析YAML文件: $yaml_file"
    
    if [[ ! -f "$yaml_file" ]]; then
        log_error "YAML文件不存在: $yaml_file"
        return 1
    fi
    
    # 文件基本信息
    local file_size=$(wc -c < "$yaml_file")
    local line_count=$(wc -l < "$yaml_file")
    log_info "文件大小: $file_size 字节"
    log_info "行数: $line_count 行"
    
    # 检查是否有未替换的环境变量
    log_info "检查未替换的环境变量..."
    if grep -n '\${' "$yaml_file" > "$LOG_DIR/unreplaced-vars.log" 2>/dev/null; then
        log_warn "发现未替换的环境变量:"
        cat "$LOG_DIR/unreplaced-vars.log" | while read -r line; do
            log_warn "  $line"
        done
    else
        log_success "所有环境变量已正确替换"
    fi
    
    # Python YAML语法验证
    log_info "执行Python YAML语法验证..."
    local python_output
    python_output=$(python3 -c "
import yaml
import sys
try:
    with open('$yaml_file', 'r') as f:
        config = yaml.safe_load(f)
    print('✓ YAML语法正确')
    print(f'✓ 配置包含 {len(config)} 个顶级键')
    
    # 检查必需字段
    required = ['port', 'proxies', 'proxy-groups', 'rules']
    missing = [k for k in required if k not in config]
    if missing:
        print(f'✗ 缺少必需字段: {missing}')
        sys.exit(1)
    else:
        print('✓ 所有必需字段都存在')
        
    # 统计信息
    print(f'✓ 代理数量: {len(config.get(\"proxies\", []))}')
    print(f'✓ 代理组数量: {len(config.get(\"proxy-groups\", []))}')
    print(f'✓ 规则数量: {len(config.get(\"rules\", []))}')
    
except yaml.YAMLError as e:
    print(f'✗ YAML语法错误: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ 验证错误: {e}')
    sys.exit(1)
" 2>&1)
    
    # 保存Python输出
    local python_log=$(save_data "python-validation" "$python_output")
    
    # 逐行显示Python输出
    echo "$python_output" | while IFS= read -r line; do
        if [[ "$line" == *"✓"* ]]; then
            log_success "$line"
        elif [[ "$line" == *"✗"* ]]; then
            log_error "$line"
        else
            log_info "$line"
        fi
    done
    
    return ${PIPESTATUS[0]}
}

# 独立的配置生成测试
test_config_generation() {
    local env_file="${1:-.env}"
    
    log_info "开始独立配置生成测试"
    log_info "环境文件: $env_file"
    log_info "日志文件: $DEBUG_LOG"
    
    # 检查必要文件
    if [[ ! -f "$env_file" ]]; then
        log_error "环境文件不存在: $env_file"
        return 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/config/clash-template.yaml" ]]; then
        log_error "配置模板不存在: $PROJECT_DIR/config/clash-template.yaml"
        return 1
    fi
    
    # 加载环境变量
    log_info "加载环境变量..."
    set -a
    source "$env_file"
    set +a
    log_success "环境变量已加载"
    
    # 显示关键环境变量
    log_debug "关键环境变量值:"
    for var in CLASH_HTTP_PORT CLASH_SECRET JP_DIRECT_UUID SJC_DIRECT_UUID; do
        if [[ -n "${!var:-}" ]]; then
            if [[ "$var" == *"SECRET"* ]] || [[ "$var" == *"PASSWORD"* ]]; then
                log_debug "  $var = [已设置，长度: ${#!var}]"
            else
                log_debug "  $var = ${!var}"
            fi
        else
            log_warn "  $var = [未设置]"
        fi
    done
    
    # 生成配置
    log_info "生成配置文件..."
    local temp_config="$LOG_DIR/test-config-$(date +%s).yaml"
    local envsubst_error_log="$LOG_DIR/envsubst-error.log"
    
    if ! envsubst < "$PROJECT_DIR/config/clash-template.yaml" > "$temp_config" 2> "$envsubst_error_log"; then
        log_error "envsubst 失败，退出码: $?"
        if [[ -s "$envsubst_error_log" ]]; then
            log_error "envsubst 错误详情:"
            sed 's/^/    /' "$envsubst_error_log" | tee -a "$DEBUG_LOG"
        fi
        return 1
    fi
    
    log_success "配置文件已生成: $temp_config"
    
    # 分析生成的配置
    analyze_yaml "$temp_config"
    local analysis_result=$?
    
    if [[ $analysis_result -eq 0 ]]; then
        log_success "配置生成和验证完全成功！"
        log_info "生成的配置文件: $temp_config"
    else
        log_error "配置验证失败"
    fi
    
    return $analysis_result
}

# 检查Docker环境中的问题
check_docker_environment() {
    log_info "检查Docker环境配置..."
    
    # 检查compose文件
    if [[ -f "$PROJECT_DIR/compose.yml" ]]; then
        log_info "检查compose.yml中的config-generator配置..."
        if grep -A 20 "config-generator:" "$PROJECT_DIR/compose.yml" > "$LOG_DIR/compose-config.log"; then
            log_debug "config-generator配置:"
            sed 's/^/    /' "$LOG_DIR/compose-config.log" | tee -a "$DEBUG_LOG"
        fi
    fi
    
    # 检查.env文件
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        local env_lines=$(wc -l < "$PROJECT_DIR/.env")
        log_info ".env文件包含 $env_lines 行配置"
        
        # 统计配置项
        local uuid_count=$(grep -c "_UUID=" "$PROJECT_DIR/.env" || echo "0")
        local domain_count=$(grep -c "_SERVER=" "$PROJECT_DIR/.env" || echo "0")
        log_debug "UUID配置项: $uuid_count 个"
        log_debug "服务器域名配置项: $domain_count 个"
    fi
}

# 主函数
main() {
    echo "================================================================"
    echo "Clash Docker 配置调试工具"
    echo "================================================================"
    
    local mode="${1:-test}"
    local env_file="${2:-.env}"
    
    case "$mode" in
        "test")
            test_config_generation "$env_file"
            ;;
        "docker")
            check_docker_environment
            ;;
        "analyze")
            if [[ -n "${3:-}" ]]; then
                analyze_yaml "$3"
            else
                log_error "请提供要分析的YAML文件路径"
                return 1
            fi
            ;;
        *)
            echo "使用方法:"
            echo "  $0 test [env_file]     # 测试配置生成 (默认)"
            echo "  $0 docker              # 检查Docker环境"
            echo "  $0 analyze <yaml_file> # 分析YAML文件"
            return 1
            ;;
    esac
    
    echo ""
    echo "================================================================"
    echo "详细日志已保存到: $DEBUG_LOG"
    echo "日志目录: $LOG_DIR"
    echo "================================================================"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi