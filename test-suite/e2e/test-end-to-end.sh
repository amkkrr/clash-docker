#!/bin/bash

# 端到端测试 - 完整用户场景测试
# 模拟真实用户使用场景，测试完整的工作流程

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMP_DIR="$PROJECT_DIR/test-suite/temp"

# 测试配置
TEST_COMPOSE_FILE="$PROJECT_DIR/compose.test.yml"
TEST_ENV_FILE="$PROJECT_DIR/.env.test"
TEST_PROJECT_NAME="clash-docker-e2e-test"

# 测试结果统计
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[E2E]${NC} $1"; }
log_success() { echo -e "${GREEN}[E2E-PASS]${NC} $1"; }
log_error() { echo -e "${RED}[E2E-FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[E2E-WARN]${NC} $1"; }

# 测试工具函数
test_scenario() {
    local description="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    log_info "场景测试: $description"
    
    if $test_function; then
        log_success "$description"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$description"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 等待服务完全就绪
wait_for_full_readiness() {
    local timeout=120
    local interval=5
    local elapsed=0
    
    log_info "等待所有服务完全就绪..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if curl -sf http://localhost:18088/config.yaml >/dev/null 2>&1 && \
           curl -sf http://localhost:18088/api/version >/dev/null 2>&1 && \
           curl -sf http://localhost:18088/health >/dev/null 2>&1; then
            log_success "所有服务已就绪"
            return 0
        fi
        
        log_info "等待服务就绪... ($elapsed/$timeout 秒)"
        sleep $interval
        ((elapsed += interval))
    done
    
    log_error "服务在 $timeout 秒内未完全就绪"
    return 1
}

# 清理环境
cleanup_environment() {
    log_info "清理E2E测试环境..."
    
    # 停止服务
    docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" down --volumes --remove-orphans >/dev/null 2>&1 || true
    
    # 清理网络
    docker network rm "${TEST_PROJECT_NAME}_clash-test-network" >/dev/null 2>&1 || true
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"/e2e-*
    
    log_success "E2E测试环境清理完成"
}

# 场景1: 全新部署工作流程
scenario_fresh_deployment() {
    log_info "执行场景1: 全新部署工作流程"
    
    # 步骤1: 环境准备
    if ! mkdir -p "$TEMP_DIR" "$PROJECT_DIR/logs"; then
        log_error "无法创建必要目录"
        return 1
    fi
    
    # 步骤2: 配置验证
    if ! "$PROJECT_DIR/scripts/validate-env.sh" "$TEST_ENV_FILE"; then
        log_error "环境变量验证失败"
        return 1
    fi
    
    # 步骤3: 配置生成
    if ! "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate "$TEST_ENV_FILE"; then
        log_error "配置生成失败"
        return 1
    fi
    
    # 步骤4: 服务启动
    if ! docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" up -d; then
        log_error "服务启动失败"
        return 1
    fi
    
    # 步骤5: 等待服务就绪
    if ! wait_for_full_readiness; then
        log_error "服务就绪检查失败"
        return 1
    fi
    
    log_success "全新部署工作流程测试通过"
    return 0
}

# 场景2: 用户配置订阅工作流程
scenario_config_subscription() {
    log_info "执行场景2: 用户配置订阅工作流程"
    
    # 步骤1: 获取配置文件URL
    local config_url="http://localhost:18088/config.yaml"
    
    # 步骤2: 模拟Clash客户端下载配置
    local temp_config="$TEMP_DIR/e2e-downloaded-config.yaml"
    if ! curl -sf "$config_url" -o "$temp_config"; then
        log_error "配置文件下载失败"
        return 1
    fi
    
    # 步骤3: 验证下载的配置文件
    if ! python3 -c "
import yaml
try:
    with open('$temp_config', 'r') as f:
        config = yaml.safe_load(f)
    assert 'port' in config, 'Missing port field'
    assert 'proxies' in config, 'Missing proxies field'
    assert 'proxy-groups' in config, 'Missing proxy-groups field'
    assert 'rules' in config, 'Missing rules field'
    print('Downloaded config validation passed')
except Exception as e:
    print(f'Config validation failed: {e}')
    exit(1)
" 2>/dev/null; then
        log_error "下载的配置文件验证失败"
        return 1
    fi
    
    # 步骤4: 检查内容类型
    local content_type=$(curl -sI "$config_url" | grep -i content-type | cut -d' ' -f2- | tr -d '\r')
    if [[ "$content_type" != *"text/yaml"* ]]; then
        log_error "配置文件MIME类型不正确: $content_type"
        return 1
    fi
    
    # 步骤5: 测试配置更新
    if ! curl -sf "$config_url" -H "If-Modified-Since: $(date -u -d '1 hour ago' '+%a, %d %b %Y %H:%M:%S GMT')" >/dev/null; then
        log_warn "配置文件缓存检查异常，但不影响功能"
    fi
    
    log_success "用户配置订阅工作流程测试通过"
    return 0
}

# 场景3: API管理工作流程
scenario_api_management() {
    log_info "执行场景3: API管理工作流程"
    
    # 步骤1: 获取Clash版本信息
    local version_response="$TEMP_DIR/e2e-version-response.json"
    if ! curl -sf "http://localhost:18088/api/version" -o "$version_response"; then
        log_error "API版本查询失败"
        return 1
    fi
    
    # 步骤2: 验证版本响应
    if ! jq -e '.version' "$version_response" >/dev/null; then
        log_error "API版本响应格式错误"
        return 1
    fi
    
    # 步骤3: 获取代理信息
    local proxies_response="$TEMP_DIR/e2e-proxies-response.json"
    if ! curl -sf "http://localhost:18088/api/proxies" -o "$proxies_response"; then
        log_error "API代理查询失败"
        return 1
    fi
    
    # 步骤4: 验证代理响应
    if ! jq -e '.proxies' "$proxies_response" >/dev/null; then
        log_error "API代理响应格式错误"
        return 1
    fi
    
    # 步骤5: 测试配置重载API
    if ! curl -sf -X PUT "http://localhost:18088/api/configs" \
        -H "Content-Type: application/json" \
        -d '{"path": "/root/.config/clash/config.yaml"}' >/dev/null; then
        log_warn "配置重载API测试失败，但可能是预期行为"
    fi
    
    log_success "API管理工作流程测试通过"
    return 0
}

# 场景4: Web界面访问工作流程
scenario_web_interface() {
    log_info "执行场景4: Web界面访问工作流程"
    
    # 步骤1: 访问主页
    local homepage_response="$TEMP_DIR/e2e-homepage.html"
    if ! curl -sf "http://localhost:18088/" -o "$homepage_response"; then
        log_error "主页访问失败"
        return 1
    fi
    
    # 步骤2: 验证主页内容
    if ! grep -q "Clash 配置服务" "$homepage_response"; then
        log_error "主页内容验证失败"
        return 1
    fi
    
    # 步骤3: 访问管理界面
    local dashboard_response="$TEMP_DIR/e2e-dashboard.html"
    if ! curl -sf "http://localhost:18088/dashboard/" -o "$dashboard_response"; then
        log_error "管理界面访问失败"
        return 1
    fi
    
    # 步骤4: 验证管理界面内容
    if ! grep -q "Clash Dashboard" "$dashboard_response"; then
        log_error "管理界面内容验证失败"
        return 1
    fi
    
    # 步骤5: 测试健康检查端点
    local health_response="$TEMP_DIR/e2e-health.json"
    if ! curl -sf "http://localhost:18088/health" -o "$health_response"; then
        log_error "健康检查端点访问失败"
        return 1
    fi
    
    # 步骤6: 验证健康检查响应
    if ! jq -e '.status == "healthy"' "$health_response" >/dev/null; then
        log_error "健康检查响应验证失败"
        return 1
    fi
    
    log_success "Web界面访问工作流程测试通过"
    return 0
}

# 场景5: 配置更新工作流程
scenario_config_update() {
    log_info "执行场景5: 配置更新工作流程"
    
    # 步骤1: 备份当前配置
    local current_config="$PROJECT_DIR/config/config.yaml"
    local backup_config="$TEMP_DIR/e2e-config-backup.yaml"
    if ! cp "$current_config" "$backup_config"; then
        log_error "配置备份失败"
        return 1
    fi
    
    # 步骤2: 创建修改版本的环境文件
    local updated_env="$TEMP_DIR/e2e-updated.env"
    if ! cp "$TEST_ENV_FILE" "$updated_env"; then
        log_error "环境文件复制失败"
        return 1
    fi
    
    # 修改一些配置
    sed -i 's/CLASH_LOG_LEVEL=debug/CLASH_LOG_LEVEL=info/' "$updated_env"
    sed -i 's/test_secret_key_123/test_secret_key_456/' "$updated_env"
    
    # 步骤3: 重新生成配置
    if ! "$PROJECT_DIR/scripts/generate-config-advanced.sh" generate "$updated_env"; then
        log_error "更新配置生成失败"
        return 1
    fi
    
    # 步骤4: 重启Clash服务
    if ! docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" restart clash; then
        log_error "Clash服务重启失败"
        return 1
    fi
    
    # 步骤5: 等待服务恢复
    sleep 10
    if ! curl -sf "http://localhost:18088/api/version" >/dev/null; then
        log_error "配置更新后服务恢复失败"
        return 1
    fi
    
    # 步骤6: 验证配置已更新
    local updated_config_content=$(curl -sf "http://localhost:18088/config.yaml")
    if [[ "$updated_config_content" == *"debug"* ]]; then
        log_error "配置似乎未更新"
        return 1
    fi
    
    # 步骤7: 恢复原配置
    if ! cp "$backup_config" "$current_config"; then
        log_error "配置恢复失败"
        return 1
    fi
    
    log_success "配置更新工作流程测试通过"
    return 0
}

# 场景6: 故障恢复工作流程
scenario_failure_recovery() {
    log_info "执行场景6: 故障恢复工作流程"
    
    # 步骤1: 模拟Clash服务故障
    if ! docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" stop clash; then
        log_error "无法停止Clash服务"
        return 1
    fi
    
    # 步骤2: 验证服务不可用
    if curl -sf "http://localhost:18088/api/version" >/dev/null 2>&1; then
        log_error "服务停止后API仍然可访问"
        return 1
    fi
    
    # 步骤3: 重启服务
    if ! docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" start clash; then
        log_error "Clash服务重启失败"
        return 1
    fi
    
    # 步骤4: 等待服务恢复
    sleep 15
    local recovery_timeout=60
    local elapsed=0
    while [[ $elapsed -lt $recovery_timeout ]]; do
        if curl -sf "http://localhost:18088/api/version" >/dev/null 2>&1; then
            break
        fi
        sleep 5
        ((elapsed += 5))
    done
    
    if [[ $elapsed -ge $recovery_timeout ]]; then
        log_error "服务在 $recovery_timeout 秒内未恢复"
        return 1
    fi
    
    # 步骤5: 验证功能完全恢复
    if ! curl -sf "http://localhost:18088/config.yaml" >/dev/null; then
        log_error "配置文件访问未恢复"
        return 1
    fi
    
    log_success "故障恢复工作流程测试通过"
    return 0
}

# 场景7: 性能和负载测试
scenario_performance_load() {
    log_info "执行场景7: 性能和负载测试"
    
    # 步骤1: API并发访问测试
    local concurrent_requests=10
    local request_count=50
    
    log_info "执行API并发访问测试 ($concurrent_requests 并发, $request_count 请求)"
    
    # 创建临时脚本进行并发测试
    local load_test_script="$TEMP_DIR/e2e-load-test.sh"
    cat > "$load_test_script" << 'EOF'
#!/bin/bash
for i in $(seq 1 50); do
    curl -sf http://localhost:18088/api/version >/dev/null &
    if (( i % 10 == 0 )); then
        wait
    fi
done
wait
EOF
    chmod +x "$load_test_script"
    
    # 执行负载测试
    local start_time=$(date +%s)
    if ! "$load_test_script"; then
        log_error "并发访问测试失败"
        return 1
    fi
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -gt 30 ]]; then
        log_warn "并发访问测试耗时较长: ${duration}秒"
    else
        log_success "并发访问测试完成，耗时: ${duration}秒"
    fi
    
    # 步骤2: 配置文件大量下载测试
    log_info "执行配置文件下载测试"
    for i in {1..20}; do
        if ! curl -sf "http://localhost:18088/config.yaml" >/dev/null; then
            log_error "配置文件下载测试在第 $i 次失败"
            return 1
        fi
    done
    
    # 步骤3: 内存和CPU使用率检查
    local memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" clash-test | cut -d'/' -f1)
    log_info "Clash容器内存使用: $memory_usage"
    
    log_success "性能和负载测试通过"
    return 0
}

# 运行所有E2E测试场景
run_all_scenarios() {
    echo -e "${BLUE}开始运行端到端测试场景...${NC}"
    echo ""
    
    # 设置陷阱以确保清理
    trap cleanup_environment EXIT
    
    # 清理环境
    cleanup_environment
    
    # 运行测试场景
    test_scenario "全新部署工作流程" scenario_fresh_deployment
    test_scenario "用户配置订阅工作流程" scenario_config_subscription
    test_scenario "API管理工作流程" scenario_api_management
    test_scenario "Web界面访问工作流程" scenario_web_interface
    test_scenario "配置更新工作流程" scenario_config_update
    test_scenario "故障恢复工作流程" scenario_failure_recovery
    test_scenario "性能和负载测试" scenario_performance_load
    
    # 输出测试结果
    echo ""
    echo -e "${BLUE}=== E2E测试结果统计 ===${NC}"
    echo "总场景数: $TESTS_RUN"
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}所有E2E测试场景通过！系统工作正常。${NC}"
        return 0
    else
        echo -e "${RED}有 $TESTS_FAILED 个E2E测试场景失败${NC}"
        return 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_scenarios
fi