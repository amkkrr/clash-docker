#!/bin/bash

# 集成测试 - Docker服务集成测试
# 测试Docker Compose服务的启动、通信和功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMP_DIR="$PROJECT_DIR/test-suite/temp"

# 测试配置
TEST_COMPOSE_FILE="$PROJECT_DIR/compose.test.yml"
TEST_ENV_FILE="$PROJECT_DIR/.env.test"
TEST_PROJECT_NAME="clash-docker-test"

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
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 测试工具函数
test_assert() {
    local description="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    
    ((TESTS_RUN++))
    log_info "测试: $description"
    
    if eval "$command" >/dev/null 2>&1; then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        log_success "$description"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$description (expected exit code $expected_exit_code, got $actual_exit_code)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 等待服务就绪
wait_for_service() {
    local service_name="$1"
    local health_check="$2"
    local timeout="${3:-60}"
    local interval="${4:-2}"
    
    log_info "等待服务 $service_name 就绪..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$health_check" >/dev/null 2>&1; then
            log_success "服务 $service_name 已就绪"
            return 0
        fi
        sleep $interval
        ((elapsed += interval))
    done
    
    log_error "服务 $service_name 在 $timeout 秒内未就绪"
    return 1
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 停止并移除测试容器
    docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" down --volumes --remove-orphans >/dev/null 2>&1 || true
    
    # 清理网络（如果存在）
    docker network rm "${TEST_PROJECT_NAME}_clash-test-network" >/dev/null 2>&1 || true
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"/*.flag "$TEMP_DIR"/*.pid
    
    log_success "测试环境清理完成"
}

# 设置测试环境
setup_test_environment() {
    log_info "设置测试环境..."
    
    # 确保目录存在
    mkdir -p "$TEMP_DIR" "$PROJECT_DIR/logs"
    
    # 检查必要文件
    if [[ ! -f "$TEST_COMPOSE_FILE" ]]; then
        log_error "测试compose文件不存在: $TEST_COMPOSE_FILE"
        return 1
    fi
    
    if [[ ! -f "$TEST_ENV_FILE" ]]; then
        log_error "测试环境文件不存在: $TEST_ENV_FILE"
        return 1
    fi
    
    # 清理之前的环境
    cleanup_test_environment
    
    log_success "测试环境设置完成"
}

# 测试配置生成
test_config_generation() {
    echo -e "${YELLOW}=== 测试配置生成 ===${NC}"
    
    test_assert "环境变量验证应该通过" \
        "$PROJECT_DIR/scripts/validate-env.sh $TEST_ENV_FILE"
    
    test_assert "配置生成应该成功" \
        "$PROJECT_DIR/scripts/generate-config-advanced.sh generate $TEST_ENV_FILE"
    
    test_assert "生成的配置文件应该存在" \
        "test -f $PROJECT_DIR/config/config.yaml"
    
    test_assert "配置文件应该包含必要内容" \
        "grep -q 'port:' $PROJECT_DIR/config/config.yaml && grep -q 'proxies:' $PROJECT_DIR/config/config.yaml"
}

# 测试Docker服务启动
test_service_startup() {
    echo -e "${YELLOW}=== 测试服务启动 ===${NC}"
    
    log_info "启动Docker Compose服务..."
    if docker compose -f "$TEST_COMPOSE_FILE" -p "$TEST_PROJECT_NAME" up -d; then
        log_success "Docker Compose服务启动成功"
    else
        log_error "Docker Compose服务启动失败"
        return 1
    fi
    
    # 等待配置生成器完成
    test_assert "配置生成器应该成功完成" \
        "wait_for_service 'config-generator' 'test -f $TEMP_DIR/config-ready.flag' 30"
    
    # 等待Clash服务健康
    test_assert "Clash服务应该变为健康状态" \
        "wait_for_service 'clash' 'docker compose -f $TEST_COMPOSE_FILE -p $TEST_PROJECT_NAME exec -T clash wget --quiet --tries=1 --spider http://localhost:19090/version' 60"
    
    # 等待Nginx服务健康
    test_assert "Nginx服务应该变为健康状态" \
        "wait_for_service 'nginx' 'curl -sf http://localhost:18088/health' 30"
}

# 测试服务通信
test_service_communication() {
    echo -e "${YELLOW}=== 测试服务通信 ===${NC}"
    
    # 测试Clash API
    test_assert "Clash API应该可访问" \
        "curl -sf http://localhost:19090/version | jq -e '.version'"
    
    # 测试Nginx代理到Clash API
    test_assert "Nginx API代理应该工作" \
        "curl -sf http://localhost:18088/api/version | jq -e '.version'"
    
    # 测试配置文件访问
    test_assert "配置文件应该可通过HTTP访问" \
        "curl -sf http://localhost:18088/config.yaml | head -1 | grep -q 'port:'"
    
    # 测试YAML MIME类型
    test_assert "配置文件应该返回正确的MIME类型" \
        "curl -sI http://localhost:18088/config.yaml | grep -q 'Content-Type: text/yaml'"
}

# 测试服务健康检查
test_health_checks() {
    echo -e "${YELLOW}=== 测试健康检查 ===${NC}"
    
    # 检查所有服务状态
    local services=("clash-test" "clash-nginx-test" "clash-monitoring-test")
    
    for service in "${services[@]}"; do
        test_assert "服务 $service 应该正在运行" \
            "docker ps --format '{{.Names}}' | grep -q $service"
            
        if [[ "$service" != "clash-monitoring-test" ]]; then
            test_assert "服务 $service 应该处于健康状态" \
                "docker inspect $service | jq -e '.[0].State.Health.Status == \"healthy\"' || docker inspect $service | jq -e '.[0].State.Status == \"running\"'"
        fi
    done
}

# 测试网络连接
test_network_connectivity() {
    echo -e "${YELLOW}=== 测试网络连接 ===${NC}"
    
    # 测试容器间网络
    test_assert "Nginx应该能连接到Clash" \
        "docker compose -f $TEST_COMPOSE_FILE -p $TEST_PROJECT_NAME exec -T nginx wget --quiet --tries=1 --spider http://clash-test:19090/version"
    
    # 测试自定义网络
    test_assert "自定义网络应该存在" \
        "docker network ls | grep -q ${TEST_PROJECT_NAME}_clash-test-network"
}

# 测试配置热重载
test_config_reload() {
    echo -e "${YELLOW}=== 测试配置热重载 ===${NC}"
    
    # 修改配置并重新生成
    log_info "修改测试配置..."
    
    # 创建修改版本的环境文件
    cp "$TEST_ENV_FILE" "$TEMP_DIR/test-reload.env"
    sed -i 's/CLASH_LOG_LEVEL=debug/CLASH_LOG_LEVEL=info/' "$TEMP_DIR/test-reload.env"
    
    test_assert "配置重新生成应该成功" \
        "$PROJECT_DIR/scripts/generate-config-advanced.sh generate $TEMP_DIR/test-reload.env"
    
    # 重启clash服务以加载新配置
    test_assert "Clash服务重启应该成功" \
        "docker compose -f $TEST_COMPOSE_FILE -p $TEST_PROJECT_NAME restart clash"
    
    test_assert "重启后Clash应该恢复健康" \
        "wait_for_service 'clash-restart' 'curl -sf http://localhost:19090/version' 30"
}

# 测试错误处理
test_error_handling() {
    echo -e "${YELLOW}=== 测试错误处理 ===${NC}"
    
    # 测试无效配置
    create_invalid_config() {
        echo "invalid: yaml: content" > "$PROJECT_DIR/config/config.yaml"
    }
    
    # 备份当前配置
    cp "$PROJECT_DIR/config/config.yaml" "$TEMP_DIR/config.backup"
    
    # 创建无效配置并测试
    create_invalid_config
    
    test_assert "Clash应该拒绝无效配置" \
        "! docker compose -f $TEST_COMPOSE_FILE -p $TEST_PROJECT_NAME restart clash"
    
    # 恢复配置
    cp "$TEMP_DIR/config.backup" "$PROJECT_DIR/config/config.yaml"
    
    test_assert "恢复有效配置后Clash应该正常启动" \
        "docker compose -f $TEST_COMPOSE_FILE -p $TEST_PROJECT_NAME restart clash && wait_for_service 'clash-recovery' 'curl -sf http://localhost:19090/version' 30"
}

# 测试监控功能
test_monitoring() {
    echo -e "${YELLOW}=== 测试监控功能 ===${NC}"
    
    # 等待监控服务收集数据
    sleep 10
    
    test_assert "监控日志应该存在" \
        "test -f $PROJECT_DIR/logs/monitoring.log"
    
    test_assert "监控日志应该包含容器状态" \
        "grep -q 'Container Status' $PROJECT_DIR/logs/monitoring.log"
    
    test_assert "监控日志应该包含健康检查" \
        "grep -q 'Service Health' $PROJECT_DIR/logs/monitoring.log"
}

# 运行性能测试
test_performance() {
    echo -e "${YELLOW}=== 测试性能 ===${NC}"
    
    # 测试API响应时间
    local api_response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:18088/api/version)
    
    test_assert "API响应时间应该小于1秒" \
        "echo '$api_response_time < 1.0' | bc -l"
    
    # 测试配置文件下载时间
    local config_download_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:18088/config.yaml)
    
    test_assert "配置文件下载时间应该小于2秒" \
        "echo '$config_download_time < 2.0' | bc -l"
}

# 运行所有集成测试
run_all_tests() {
    echo -e "${BLUE}开始运行Docker服务集成测试...${NC}"
    echo ""
    
    # 设置陷阱以确保清理
    trap cleanup_test_environment EXIT
    
    # 设置测试环境
    if ! setup_test_environment; then
        log_error "测试环境设置失败"
        return 1
    fi
    
    # 运行各类测试
    test_config_generation
    test_service_startup
    test_service_communication
    test_health_checks
    test_network_connectivity
    test_config_reload
    test_error_handling
    test_monitoring
    test_performance
    
    # 输出测试结果
    echo ""
    echo -e "${BLUE}=== 集成测试结果统计 ===${NC}"
    echo "总测试数: $TESTS_RUN"
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}所有集成测试通过！${NC}"
        return 0
    else
        echo -e "${RED}有 $TESTS_FAILED 个测试失败${NC}"
        return 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi