#!/bin/bash

# 测试运行器 - 执行所有测试套件
# 按顺序运行单元测试、集成测试和端到端测试

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$SCRIPT_DIR/reports"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 测试结果
declare -A test_results
declare -A test_durations
total_tests=0
passed_tests=0
failed_tests=0

# 日志函数
log_header() { echo -e "${BOLD}${BLUE}$1${NC}"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 创建测试报告目录
setup_test_environment() {
    log_info "设置测试环境..."
    
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$SCRIPT_DIR/temp"
    
    # 创建测试报告文件
    cat > "$REPORTS_DIR/test-report.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Clash Docker 测试报告</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: #ecf0f1; padding: 20px; border-radius: 6px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; color: #34495e; }
        .metric .value { font-size: 2em; font-weight: bold; }
        .passed { color: #27ae60; }
        .failed { color: #e74c3c; }
        .warning { color: #f39c12; }
        .test-section { margin: 30px 0; padding: 20px; border: 1px solid #bdc3c7; border-radius: 6px; }
        .test-section h2 { margin-top: 0; color: #2c3e50; }
        .test-result { margin: 10px 0; padding: 10px; border-radius: 4px; }
        .test-result.pass { background: #d5f4e6; border-left: 4px solid #27ae60; }
        .test-result.fail { background: #fceaea; border-left: 4px solid #e74c3c; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #bdc3c7; text-align: center; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ Clash Docker 企业级测试报告</h1>
        <div class="timestamp">生成时间: $(date)</div>
        
        <div class="summary">
            <div class="metric">
                <h3>总测试数</h3>
                <div class="value" id="total-tests">0</div>
            </div>
            <div class="metric">
                <h3>通过测试</h3>
                <div class="value passed" id="passed-tests">0</div>
            </div>
            <div class="metric">
                <h3>失败测试</h3>
                <div class="value failed" id="failed-tests">0</div>
            </div>
            <div class="metric">
                <h3>成功率</h3>
                <div class="value" id="success-rate">0%</div>
            </div>
        </div>
        
        <div id="test-sections">
        </div>
        
        <div class="footer">
            <p>🤖 Generated with Claude Code | Clash Docker Enterprise Testing Suite</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "测试环境设置完成"
}

# 运行单个测试套件
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local description="$3"
    
    log_header "运行 $suite_name 测试套件: $description"
    
    if [[ ! -f "$test_script" ]]; then
        log_error "测试脚本不存在: $test_script"
        test_results["$suite_name"]="SKIP"
        return 1
    fi
    
    local start_time=$(date +%s)
    local log_file="$REPORTS_DIR/${suite_name}-output.log"
    
    # 运行测试并捕获输出
    if "$test_script" 2>&1 | tee "$log_file"; then
        local exit_code=0
        test_results["$suite_name"]="PASS"
        log_success "$suite_name 测试套件通过"
        ((passed_tests++))
    else
        local exit_code=1
        test_results["$suite_name"]="FAIL"
        log_error "$suite_name 测试套件失败"
        ((failed_tests++))
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    test_durations["$suite_name"]=$duration
    
    ((total_tests++))
    
    log_info "$suite_name 测试套件耗时: ${duration}秒"
    echo ""
    
    return $exit_code
}

# 运行所有测试套件
run_all_test_suites() {
    log_header "开始执行 Clash Docker 完整测试套件"
    echo ""
    
    # 1. 单元测试
    run_test_suite "unit" "$SCRIPT_DIR/unit/test-env-validation.sh" "环境变量验证单元测试"
    
    # 2. 集成测试
    run_test_suite "integration" "$SCRIPT_DIR/integration/test-docker-services.sh" "Docker服务集成测试"
    
    # 3. 端到端测试
    run_test_suite "e2e" "$SCRIPT_DIR/e2e/test-end-to-end.sh" "端到端场景测试"
}

# 生成详细测试报告
generate_detailed_report() {
    log_info "生成详细测试报告..."
    
    local report_file="$REPORTS_DIR/test-report.html"
    local success_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( (passed_tests * 100) / total_tests ))
    fi
    
    # 更新HTML报告
    local test_sections=""
    for suite in "${!test_results[@]}"; do
        local status="${test_results[$suite]}"
        local duration="${test_durations[$suite]:-0}"
        local log_file="$REPORTS_DIR/${suite}-output.log"
        
        local status_class="pass"
        local status_icon="✅"
        if [[ "$status" == "FAIL" ]]; then
            status_class="fail"
            status_icon="❌"
        elif [[ "$status" == "SKIP" ]]; then
            status_class="warning"
            status_icon="⚠️"
        fi
        
        test_sections+="
        <div class='test-section'>
            <h2>$status_icon ${suite^} 测试套件</h2>
            <div class='test-result $status_class'>
                <strong>状态:</strong> $status<br>
                <strong>耗时:</strong> ${duration}秒<br>
                <strong>日志文件:</strong> <a href='${suite}-output.log'>${suite}-output.log</a>
            </div>
        </div>"
    done
    
    # 使用sed更新HTML文件
    sed -i "s|<div class=\"value\" id=\"total-tests\">0</div>|<div class=\"value\" id=\"total-tests\">$total_tests</div>|" "$report_file"
    sed -i "s|<div class=\"value passed\" id=\"passed-tests\">0</div>|<div class=\"value passed\" id=\"passed-tests\">$passed_tests</div>|" "$report_file"
    sed -i "s|<div class=\"value failed\" id=\"failed-tests\">0</div>|<div class=\"value failed\" id=\"failed-tests\">$failed_tests</div>|" "$report_file"
    sed -i "s|<div class=\"value\" id=\"success-rate\">0%</div>|<div class=\"value\" id=\"success-rate\">${success_rate}%</div>|" "$report_file"
    sed -i "s|<div id=\"test-sections\">.*</div>|<div id=\"test-sections\">$test_sections</div>|" "$report_file"
    
    # 生成JSON格式报告
    local json_report="$REPORTS_DIR/test-report.json"
    cat > "$json_report" << EOF
{
    "timestamp": "$(date -u -Iseconds)",
    "summary": {
        "total_tests": $total_tests,
        "passed_tests": $passed_tests,
        "failed_tests": $failed_tests,
        "success_rate": $success_rate
    },
    "test_suites": {
EOF

    local first=true
    for suite in "${!test_results[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> "$json_report"
        fi
        echo "        \"$suite\": {" >> "$json_report"
        echo "            \"status\": \"${test_results[$suite]}\"," >> "$json_report"
        echo "            \"duration\": ${test_durations[$suite]:-0}" >> "$json_report"
        echo -n "        }" >> "$json_report"
        first=false
    done

    cat >> "$json_report" << EOF

    }
}
EOF
    
    log_success "测试报告生成完成"
    log_info "HTML报告: $report_file"
    log_info "JSON报告: $json_report"
}

# 输出测试总结
print_test_summary() {
    echo ""
    log_header "🎯 测试执行总结"
    echo ""
    
    printf "%-20s %-10s %-10s\n" "测试套件" "状态" "耗时(秒)"
    printf "%-20s %-10s %-10s\n" "--------" "----" "--------"
    
    for suite in "${!test_results[@]}"; do
        local status="${test_results[$suite]}"
        local duration="${test_durations[$suite]:-0}"
        
        case "$status" in
            "PASS") status_display="${GREEN}PASS${NC}" ;;
            "FAIL") status_display="${RED}FAIL${NC}" ;;
            "SKIP") status_display="${YELLOW}SKIP${NC}" ;;
            *) status_display="$status" ;;
        esac
        
        printf "%-20s %-20s %-10s\n" "$suite" "$status_display" "$duration"
    done
    
    echo ""
    echo "📊 统计信息:"
    echo "   总测试套件: $total_tests"
    echo -e "   通过: ${GREEN}$passed_tests${NC}"
    echo -e "   失败: ${RED}$failed_tests${NC}"
    
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(( (passed_tests * 100) / total_tests ))
        echo "   成功率: ${success_rate}%"
    fi
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log_success "🎉 所有测试套件执行成功！系统质量优秀。"
    else
        log_error "❌ 有 $failed_tests 个测试套件失败，需要检查和修复。"
    fi
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 停止所有测试容器
    docker compose -f "$PROJECT_DIR/compose.test.yml" down --volumes --remove-orphans >/dev/null 2>&1 || true
    
    # 清理临时文件，保留报告
    find "$SCRIPT_DIR/temp" -name "*.tmp" -o -name "*.pid" -o -name "*.flag" -delete 2>/dev/null || true
    
    log_success "测试环境清理完成"
}

# 主函数
main() {
    local skip_cleanup=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cleanup)
                skip_cleanup=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --no-cleanup    测试后不清理环境"
                echo "  --help, -h      显示此帮助信息"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 设置陷阱函数
    if [[ "$skip_cleanup" != "true" ]]; then
        trap cleanup_test_environment EXIT
    fi
    
    # 检查依赖
    local required_commands=("docker" "curl" "jq" "python3")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "缺少必需命令: $cmd"
            exit 1
        fi
    done
    
    # 执行测试流程
    setup_test_environment
    run_all_test_suites
    generate_detailed_report
    print_test_summary
    
    # 返回适当的退出码
    if [[ $failed_tests -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi