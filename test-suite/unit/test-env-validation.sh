#!/bin/bash

# 单元测试 - 环境变量验证测试
# 测试环境变量验证脚本的各种场景

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMP_DIR="$PROJECT_DIR/test-suite/temp"
VALIDATE_SCRIPT="$PROJECT_DIR/scripts/validate-env.sh"

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

# 测试工具函数
test_assert() {
    local description="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    
    ((TESTS_RUN++))
    echo -e "${BLUE}[TEST]${NC} $description"
    
    if eval "$command" >/dev/null 2>&1; then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        echo -e "${GREEN}[PASS]${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $description (expected exit code $expected_exit_code, got $actual_exit_code)"
        ((TESTS_FAILED++))
    fi
}

# 创建测试用的环境文件
create_test_env() {
    local filename="$1"
    local content="$2"
    echo "$content" > "$TEMP_DIR/$filename"
}

# 测试有效配置
test_valid_configuration() {
    echo -e "${YELLOW}=== 测试有效配置 ===${NC}"
    
    create_test_env "valid.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
JP_HYSTERIA2_SERVER=test.example.com
JP_DIRECT_UUID=12345678-1234-1234-1234-123456789abc
SERVICE_IP_1=192.168.1.1
PRIVATE_IP_RANGE_1=192.168.0.0/24
"
    
    test_assert "有效配置应该通过验证" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/valid.env'" 0
}

# 测试无效端口
test_invalid_ports() {
    echo -e "${YELLOW}=== 测试无效端口 ===${NC}"
    
    create_test_env "invalid_port.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=70000
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
"
    
    test_assert "无效端口应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/invalid_port.env'" 1
        
    create_test_env "negative_port.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=-1
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
"
    
    test_assert "负数端口应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/negative_port.env'" 1
}

# 测试无效IP地址
test_invalid_ips() {
    echo -e "${YELLOW}=== 测试无效IP地址 ===${NC}"
    
    create_test_env "invalid_ip.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
SERVICE_IP_1=999.999.999.999
"
    
    test_assert "无效IP应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/invalid_ip.env'" 1
        
    create_test_env "malformed_ip.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
SERVICE_IP_1=not.an.ip.address
"
    
    test_assert "格式错误的IP应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/malformed_ip.env'" 1
}

# 测试无效UUID
test_invalid_uuids() {
    echo -e "${YELLOW}=== 测试无效UUID ===${NC}"
    
    create_test_env "invalid_uuid.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
JP_DIRECT_UUID=not-a-valid-uuid
"
    
    test_assert "无效UUID应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/invalid_uuid.env'" 1
        
    create_test_env "short_uuid.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
JP_DIRECT_UUID=12345678-1234-1234-1234
"
    
    test_assert "不完整的UUID应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/short_uuid.env'" 1
}

# 测试缺失必需变量
test_missing_required_vars() {
    echo -e "${YELLOW}=== 测试缺失必需变量 ===${NC}"
    
    create_test_env "missing_secret.env" "
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
"
    
    test_assert "缺失CLASH_SECRET应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/missing_secret.env'" 1
}

# 测试端口冲突
test_port_conflicts() {
    echo -e "${YELLOW}=== 测试端口冲突 ===${NC}"
    
    create_test_env "port_conflict.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7890
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
"
    
    test_assert "端口冲突应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/port_conflict.env'" 1
}

# 测试无效域名
test_invalid_domains() {
    echo -e "${YELLOW}=== 测试无效域名 ===${NC}"
    
    create_test_env "invalid_domain.env" "
CLASH_SECRET=test_secret_123456
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8080
JP_HYSTERIA2_SERVER=invalid..domain..com
"
    
    test_assert "无效域名应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/invalid_domain.env'" 1
}

# 测试文件不存在
test_file_not_found() {
    echo -e "${YELLOW}=== 测试文件不存在 ===${NC}"
    
    test_assert "不存在的文件应该验证失败" \
        "'$VALIDATE_SCRIPT' '$TEMP_DIR/nonexistent.env'" 1
}

# 运行所有测试
run_all_tests() {
    echo -e "${BLUE}开始运行环境变量验证单元测试...${NC}"
    echo ""
    
    # 确保临时目录存在
    mkdir -p "$TEMP_DIR"
    
    # 运行各类测试
    test_valid_configuration
    test_invalid_ports
    test_invalid_ips
    test_invalid_uuids
    test_missing_required_vars
    test_port_conflicts
    test_invalid_domains
    test_file_not_found
    
    # 清理测试文件
    rm -f "$TEMP_DIR"/*.env
    
    # 输出测试结果
    echo ""
    echo -e "${BLUE}=== 测试结果统计 ===${NC}"
    echo "总测试数: $TESTS_RUN"
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}所有测试通过！${NC}"
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