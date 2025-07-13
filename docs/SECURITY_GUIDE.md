# 🔐 安全配置指南

## 📚 目录

1. [安全架构概述](#安全架构概述)
2. [容器安全配置](#容器安全配置)
3. [网络安全策略](#网络安全策略)
4. [访问控制和认证](#访问控制和认证)
5. [数据保护和加密](#数据保护和加密)
6. [安全监控和审计](#安全监控和审计)
7. [安全扫描和检测](#安全扫描和检测)
8. [事件响应和恢复](#事件响应和恢复)
9. [合规性要求](#合规性要求)
10. [安全最佳实践](#安全最佳实践)

---

## 安全架构概述

### 多层防护模型

```
┌─────────────────────────────────────┐
│        外部网络边界                    │
│    (防火墙 + DDoS防护)               │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         应用层安全                    │
│   (HTTPS + 认证 + 访问控制)          │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         容器安全层                    │
│  (非root运行 + 资源限制 + 隔离)       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         主机安全层                    │
│    (内核加固 + 审计 + 监控)           │
└─────────────────────────────────────┘
```

### 安全原则

- **最小权限原则**: 只授予完成任务所需的最小权限
- **深度防护**: 多层安全控制，防止单点失效
- **默认拒绝**: 默认禁止所有访问，明确允许必要的访问
- **持续监控**: 实时监控和审计所有活动
- **快速响应**: 建立完善的事件响应机制

## 容器安全配置

### 安全的Dockerfile

创建 `security/Dockerfile.clash-secure`:
```dockerfile
# 使用官方最小镜像
FROM alpine:3.18 as builder

# 安全参数
ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

# 标签信息
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="Clash Secure" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.vendor="Clash Docker Team" \
      org.opencontainers.image.licenses="MIT"

# 安装安全工具和依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    && update-ca-certificates

# 下载和验证Clash二进制文件
ARG CLASH_VERSION=v1.18.0
ARG TARGETARCH
RUN CLASH_URL="https://github.com/Dreamacro/clash/releases/download/${CLASH_VERSION}/clash-linux-${TARGETARCH}-${CLASH_VERSION}.gz" && \
    CLASH_CHECKSUM_URL="https://github.com/Dreamacro/clash/releases/download/${CLASH_VERSION}/clash-linux-${TARGETARCH}-${CLASH_VERSION}.gz.sha256" && \
    curl -L "$CLASH_URL" -o clash.gz && \
    curl -L "$CLASH_CHECKSUM_URL" -o clash.gz.sha256 && \
    sha256sum -c clash.gz.sha256 && \
    gunzip clash.gz && \
    chmod +x clash

# 运行时镜像
FROM alpine:3.18

# 创建非特权用户
RUN addgroup -g 1000 clash && \
    adduser -D -s /bin/sh -u 1000 -G clash clash

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    tini \
    && rm -rf /var/cache/apk/*

# 复制文件
COPY --from=builder clash /usr/local/bin/clash
COPY --chown=clash:clash config/clash-template.yaml /app/config/

# 创建目录和设置权限
RUN mkdir -p /app/{config,data,logs} && \
    chown -R clash:clash /app && \
    chmod -R 750 /app

# 安全配置
RUN chmod +x /usr/local/bin/clash

# 切换到非特权用户
USER clash
WORKDIR /app

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:9090/version || exit 1

# 暴露端口 (仅监听localhost)
EXPOSE 7890 7891 9090

# 使用tini作为init进程
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["clash", "-d", "/app/config"]
```

### 安全的Docker Compose配置

创建 `security/compose.secure.yml`:
```yaml
version: '3.8'

x-security-defaults: &security-defaults
  # 安全选项
  security_opt:
    - no-new-privileges:true
    - apparmor:docker-default
    - seccomp:default
  
  # 移除所有capabilities
  cap_drop:
    - ALL
  
  # 用户和组
  user: "1000:1000"
  
  # 只读根文件系统
  read_only: true
  
  # 禁用特权模式
  privileged: false
  
  # 内存限制防止DoS
  mem_limit: 512m
  mem_reservation: 256m
  
  # CPU限制
  cpus: 1.0
  
  # 重启策略
  restart: unless-stopped

services:
  clash:
    <<: *security-defaults
    build:
      context: .
      dockerfile: security/Dockerfile.clash-secure
      args:
        BUILD_DATE: ${BUILD_DATE:-}
        VERSION: ${VERSION:-latest}
        VCS_REF: ${VCS_REF:-}
    
    # 网络安全
    networks:
      - clash-internal
    
    # 端口绑定到localhost
    ports:
      - "127.0.0.1:7890:7890"
      - "127.0.0.1:7891:7891"
      - "127.0.0.1:9090:9090"
    
    # 安全的挂载
    volumes:
      - ./config:/app/config:ro,noexec,nosuid,nodev
      - clash-data:/app/data:rw,noexec,nosuid,nodev
      - clash-logs:/app/logs:rw,noexec,nosuid,nodev
    
    # 临时文件系统
    tmpfs:
      - /tmp:noexec,nosuid,nodev,size=100m
      - /var/tmp:noexec,nosuid,nodev,size=50m
    
    # 环境变量（非敏感）
    environment:
      - TZ=UTC
      - CLASH_LOG_LEVEL=${CLASH_LOG_LEVEL:-info}
    
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # 资源限制
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
    
    # 额外的安全capabilities（最小化）
    cap_add:
      - NET_BIND_SERVICE  # 仅绑定端口需要

  nginx:
    <<: *security-defaults
    build:
      context: .
      dockerfile: security/Dockerfile.nginx-secure
    
    networks:
      - clash-internal
      - web-external
    
    ports:
      - "8088:8088"
    
    volumes:
      - ./security/nginx-security.conf:/etc/nginx/nginx.conf:ro
      - ./security/htpasswd:/etc/nginx/htpasswd:ro
      - ./html:/var/www/html:ro,noexec,nosuid,nodev
      - nginx-cache:/var/cache/nginx:rw,noexec,nosuid,nodev
      - nginx-logs:/var/log/nginx:rw,noexec,nosuid,nodev
    
    tmpfs:
      - /var/run:noexec,nosuid,nodev,size=10m
      - /tmp:noexec,nosuid,nodev,size=50m
    
    cap_add:
      - NET_BIND_SERVICE
      - CHOWN
      - SETGID
      - SETUID
    
    mem_limit: 256m
    cpus: 0.5

  # 安全扫描服务 (可选)
  security-scanner:
    image: aquasec/trivy:latest
    restart: "no"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./security/scan-results:/results:rw
    command: image --format json --output /results/scan-report.json clash-docker_clash
    profiles:
      - security-scan

networks:
  clash-internal:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.20.0.0/24
  
  web-external:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/24

volumes:
  clash-data:
    driver: local
    driver_opts:
      type: none
      o: bind,noexec,nosuid,nodev
      device: ./data
  
  clash-logs:
    driver: local
    driver_opts:
      type: none
      o: bind,noexec,nosuid,nodev
      device: ./logs
  
  nginx-cache:
    driver: local
  
  nginx-logs:
    driver: local
```

### 容器安全扫描

创建 `security/scan-containers.sh`:
```bash
#!/bin/bash
# 容器安全扫描脚本

set -euo pipefail

SCAN_DIR="./security/scan-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SCAN_DIR"

# Trivy扫描
scan_with_trivy() {
    echo "使用Trivy进行安全扫描..."
    
    local images=("clash-docker_clash" "clash-docker_nginx")
    
    for image in "${images[@]}"; do
        echo "扫描镜像: $image"
        
        # 漏洞扫描
        trivy image \
            --format json \
            --output "$SCAN_DIR/${image}_vulnerabilities_$TIMESTAMP.json" \
            "$image"
        
        # 配置扫描
        trivy image \
            --security-checks config \
            --format json \
            --output "$SCAN_DIR/${image}_config_$TIMESTAMP.json" \
            "$image"
        
        # 生成HTML报告
        trivy image \
            --format template \
            --template '@contrib/html.tpl' \
            --output "$SCAN_DIR/${image}_report_$TIMESTAMP.html" \
            "$image"
    done
}

# Docker Bench安全检查
run_docker_bench() {
    echo "运行Docker Bench安全检查..."
    
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /etc:/etc:ro \
        -v /usr/bin/docker:/usr/bin/docker:ro \
        --label docker_bench_security \
        docker/docker-bench-security > "$SCAN_DIR/docker_bench_$TIMESTAMP.txt"
}

# 自定义安全检查
custom_security_checks() {
    echo "执行自定义安全检查..."
    
    local report="$SCAN_DIR/custom_security_$TIMESTAMP.txt"
    
    {
        echo "=== 自定义安全检查报告 ==="
        echo "时间: $(date)"
        echo ""
        
        echo "=== 容器运行用户检查 ==="
        docker compose exec -T clash whoami
        docker compose exec -T nginx whoami
        echo ""
        
        echo "=== 端口绑定检查 ==="
        netstat -tlnp | grep -E ':(7890|7891|8088|9090)'
        echo ""
        
        echo "=== 文件权限检查 ==="
        ls -la config/
        echo ""
        
        echo "=== 容器Capabilities检查 ==="
        docker inspect clash-docker_clash_1 | jq '.[0].HostConfig.CapAdd'
        docker inspect clash-docker_clash_1 | jq '.[0].HostConfig.CapDrop'
        echo ""
        
        echo "=== 资源限制检查 ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
        
    } > "$report"
    
    echo "自定义检查完成: $report"
}

# 生成安全评估报告
generate_security_report() {
    echo "生成安全评估报告..."
    
    local report="$SCAN_DIR/security_assessment_$TIMESTAMP.md"
    
    cat > "$report" << EOF
# 安全评估报告

**生成时间**: $(date)
**扫描范围**: Clash Docker 应用栈

## 扫描结果摘要

### 镜像漏洞扫描
$(find "$SCAN_DIR" -name "*vulnerabilities_$TIMESTAMP.json" -exec echo "- {}" \;)

### 配置安全检查
$(find "$SCAN_DIR" -name "*config_$TIMESTAMP.json" -exec echo "- {}" \;)

### Docker Bench检查
- docker_bench_$TIMESTAMP.txt

### 自定义安全检查
- custom_security_$TIMESTAMP.txt

## 风险评估

### 高风险问题
$(grep -l "HIGH\|CRITICAL" "$SCAN_DIR"/*_$TIMESTAMP.* | head -5 || echo "无高风险问题发现")

### 中风险问题
$(grep -l "MEDIUM" "$SCAN_DIR"/*_$TIMESTAMP.* | head -5 || echo "无中风险问题发现")

## 修复建议

1. 定期更新基础镜像
2. 应用安全补丁
3. 检查配置文件权限
4. 监控运行时异常

## 下次扫描计划

建议每周进行一次安全扫描，或在版本更新后立即扫描。

---
**报告生成工具**: Clash Docker 安全扫描工具
**版本**: 1.0.0
EOF

    echo "安全评估报告生成完成: $report"
}

# 主扫描流程
main() {
    echo "开始安全扫描 - $TIMESTAMP"
    
    scan_with_trivy
    run_docker_bench
    custom_security_checks
    generate_security_report
    
    echo "安全扫描完成 - $TIMESTAMP"
    echo "扫描结果保存在: $SCAN_DIR"
}

main "$@"
```

## 网络安全策略

### 防火墙配置

#### iptables规则

创建 `security/firewall-rules.sh`:
```bash
#!/bin/bash
# 防火墙规则配置

set -euo pipefail

# 清除现有规则
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# 设置默认策略
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 允许loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH访问 (限制源IP)
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT

# Web服务端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8088 -j ACCEPT

# 限制并发连接数
iptables -A INPUT -p tcp --dport 8088 -m connlimit --connlimit-above 100 -j REJECT

# DDoS防护
iptables -A INPUT -p tcp --dport 8088 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

# 阻止Clash代理端口的外部访问
iptables -A INPUT -p tcp --dport 7890 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 7891 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 9090 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 7890 -j REJECT
iptables -A INPUT -p tcp --dport 7891 -j REJECT
iptables -A INPUT -p tcp --dport 9090 -j REJECT

# 记录被拒绝的连接
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# 最终拒绝所有其他连接
iptables -A INPUT -j REJECT

# 保存规则
iptables-save > /etc/iptables/rules.v4

echo "防火墙规则配置完成"
```

#### UFW简化配置

```bash
#!/bin/bash
# UFW防火墙配置

# 重置UFW
ufw --force reset

# 默认策略
ufw default deny incoming
ufw default allow outgoing

# SSH访问
ufw allow ssh

# Web服务
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8088/tcp

# 限制连接速率
ufw limit ssh
ufw limit 8088/tcp

# 拒绝代理端口的外部访问
ufw deny 7890
ufw deny 7891
ufw deny 9090

# 启用UFW
ufw --force enable

echo "UFW防火墙配置完成"
```

### 网络隔离

#### Docker网络安全配置

```yaml
# 安全的网络配置
networks:
  # 内部网络 - 完全隔离
  clash-internal:
    driver: bridge
    internal: true
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
      com.docker.network.bridge.enable_ip_masquerade: "false"
  
  # 外部网络 - 受限访问
  web-external:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.21.0.0/24
          gateway: 172.21.0.1
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

## 访问控制和认证

### 多层认证配置

#### HTTP基本认证

创建 `security/setup-auth.sh`:
```bash
#!/bin/bash
# 设置HTTP认证

USERNAME="${1:-admin}"
PASSWORD="${2:-}"

if [ -z "$PASSWORD" ]; then
    echo "请输入密码:"
    read -s PASSWORD
fi

# 生成密码哈希
htpasswd -c security/htpasswd "$USERNAME" <<< "$PASSWORD"

# 设置权限
chmod 640 security/htpasswd
chown root:docker security/htpasswd

echo "HTTP认证配置完成"
echo "用户名: $USERNAME"
```

#### JWT令牌认证

创建 `security/jwt-auth.lua` (Nginx Lua脚本):
```lua
-- JWT认证模块
local jwt = require "resty.jwt"

-- 配置
local jwt_secret = os.getenv("JWT_SECRET") or "your-secret-key"
local jwt_token = ngx.var.http_authorization

-- 验证JWT令牌
if not jwt_token then
    ngx.status = 401
    ngx.say("Missing Authorization header")
    ngx.exit(401)
end

-- 提取Bearer令牌
local token = string.match(jwt_token, "Bearer%s+(.+)")
if not token then
    ngx.status = 401
    ngx.say("Invalid Authorization format")
    ngx.exit(401)
end

-- 验证JWT
local jwt_obj = jwt:verify(jwt_secret, token)
if not jwt_obj.valid then
    ngx.status = 401
    ngx.say("Invalid JWT token")
    ngx.exit(401)
end

-- 检查过期时间
local now = ngx.time()
if jwt_obj.payload.exp and jwt_obj.payload.exp < now then
    ngx.status = 401
    ngx.say("JWT token expired")
    ngx.exit(401)
end

-- 设置用户信息
ngx.var.authenticated_user = jwt_obj.payload.sub or "unknown"
```

#### API密钥认证

创建 `security/api-key-auth.sh`:
```bash
#!/bin/bash
# API密钥管理

ACTION="$1"
KEY_NAME="$2"

API_KEYS_FILE="security/api-keys.json"

# 生成新的API密钥
generate_key() {
    local key_name="$1"
    local api_key=$(openssl rand -hex 32)
    local key_hash=$(echo -n "$api_key" | sha256sum | cut -d' ' -f1)
    
    # 保存到密钥文件
    if [ ! -f "$API_KEYS_FILE" ]; then
        echo '{}' > "$API_KEYS_FILE"
    fi
    
    jq --arg name "$key_name" --arg hash "$key_hash" --arg created "$(date -Iseconds)" \
       '.[$name] = {hash: $hash, created: $created, active: true}' \
       "$API_KEYS_FILE" > "$API_KEYS_FILE.tmp" && \
       mv "$API_KEYS_FILE.tmp" "$API_KEYS_FILE"
    
    echo "API密钥生成成功:"
    echo "名称: $key_name"
    echo "密钥: $api_key"
    echo "请妥善保存此密钥，系统不会再次显示"
}

# 验证API密钥
verify_key() {
    local api_key="$1"
    local key_hash=$(echo -n "$api_key" | sha256sum | cut -d' ' -f1)
    
    if [ ! -f "$API_KEYS_FILE" ]; then
        return 1
    fi
    
    # 检查密钥是否存在且活跃
    if jq -e --arg hash "$key_hash" 'to_entries[] | select(.value.hash == $hash and .value.active == true)' "$API_KEYS_FILE" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# 撤销API密钥
revoke_key() {
    local key_name="$1"
    
    jq --arg name "$key_name" '.[$name].active = false' \
       "$API_KEYS_FILE" > "$API_KEYS_FILE.tmp" && \
       mv "$API_KEYS_FILE.tmp" "$API_KEYS_FILE"
    
    echo "API密钥已撤销: $key_name"
}

case "$ACTION" in
    "generate")
        generate_key "$KEY_NAME"
        ;;
    "verify")
        if verify_key "$KEY_NAME"; then
            echo "API密钥有效"
            exit 0
        else
            echo "API密钥无效"
            exit 1
        fi
        ;;
    "revoke")
        revoke_key "$KEY_NAME"
        ;;
    *)
        echo "用法: $0 {generate|verify|revoke} <key_name_or_key>"
        exit 1
        ;;
esac
```

### IP白名单

创建 `security/ip-whitelist.conf`:
```nginx
# IP白名单配置

# 管理接口访问控制
location /api/admin {
    # 内网IP
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    
    # 特定管理IP
    allow 203.0.113.10;  # 管理员办公网络
    allow 198.51.100.20; # VPN出口IP
    
    # 拒绝其他所有IP
    deny all;
    
    proxy_pass http://clash_backend;
}

# 配置文件访问控制
location /config.yaml {
    # 允许更广泛的访问
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    allow 100.64.0.0/10;  # CGNAT
    
    # CDN IP段
    include /etc/nginx/conf.d/cdn-ips.conf;
    
    deny all;
    
    proxy_pass http://clash_backend;
}

# 动态IP白名单更新
location /auth/whitelist {
    # 仅允许本地更新
    allow 127.0.0.1;
    deny all;
    
    content_by_lua_block {
        -- 验证API密钥
        local auth_header = ngx.var.http_x_api_key
        if not auth_header then
            ngx.status = 401
            ngx.say("Missing API key")
            return
        end
        
        -- 这里实现动态白名单更新逻辑
        -- 可以与外部认证系统集成
    }
}
```

## 数据保护和加密

### 敏感数据加密

#### 环境变量加密

创建 `security/encrypt-env.sh`:
```bash
#!/bin/bash
# 环境变量加密工具

set -euo pipefail

MASTER_KEY_FILE="security/master.key"
ENCRYPTED_ENV_FILE="security/.env.encrypted"

# 生成主密钥
generate_master_key() {
    if [ ! -f "$MASTER_KEY_FILE" ]; then
        openssl rand -base64 32 > "$MASTER_KEY_FILE"
        chmod 600 "$MASTER_KEY_FILE"
        echo "主密钥已生成: $MASTER_KEY_FILE"
    else
        echo "主密钥已存在: $MASTER_KEY_FILE"
    fi
}

# 加密环境文件
encrypt_env() {
    local env_file="${1:-.env}"
    
    if [ ! -f "$env_file" ]; then
        echo "错误: 环境文件不存在: $env_file"
        exit 1
    fi
    
    # 读取主密钥
    local master_key=$(cat "$MASTER_KEY_FILE")
    
    # 加密文件
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$env_file" \
        -out "$ENCRYPTED_ENV_FILE" \
        -pass pass:"$master_key"
    
    echo "环境文件已加密: $ENCRYPTED_ENV_FILE"
}

# 解密环境文件
decrypt_env() {
    local output_file="${1:-.env.decrypted}"
    
    if [ ! -f "$ENCRYPTED_ENV_FILE" ]; then
        echo "错误: 加密文件不存在: $ENCRYPTED_ENV_FILE"
        exit 1
    fi
    
    # 读取主密钥
    local master_key=$(cat "$MASTER_KEY_FILE")
    
    # 解密文件
    openssl enc -aes-256-cbc -d -pbkdf2 \
        -in "$ENCRYPTED_ENV_FILE" \
        -out "$output_file" \
        -pass pass:"$master_key"
    
    echo "环境文件已解密: $output_file"
}

# 安全删除明文文件
secure_delete() {
    local file="$1"
    
    if [ -f "$file" ]; then
        # 多次覆写文件
        shred -vfz -n 3 "$file"
        echo "文件已安全删除: $file"
    fi
}

case "${1:-help}" in
    "generate-key")
        generate_master_key
        ;;
    "encrypt")
        generate_master_key
        encrypt_env "$2"
        ;;
    "decrypt")
        decrypt_env "$2"
        ;;
    "secure-delete")
        secure_delete "$2"
        ;;
    *)
        echo "用法: $0 {generate-key|encrypt|decrypt|secure-delete} [file]"
        echo ""
        echo "命令:"
        echo "  generate-key    - 生成主加密密钥"
        echo "  encrypt [file]  - 加密环境文件"
        echo "  decrypt [file]  - 解密环境文件"
        echo "  secure-delete   - 安全删除文件"
        ;;
esac
```

#### 密钥管理

创建 `security/key-management.sh`:
```bash
#!/bin/bash
# 密钥管理系统

set -euo pipefail

KEYSTORE_DIR="security/keystore"
BACKUP_DIR="security/key-backups"

mkdir -p "$KEYSTORE_DIR" "$BACKUP_DIR"

# 生成服务密钥
generate_service_key() {
    local service_name="$1"
    local key_type="${2:-rsa}"  # rsa, ecdsa, ed25519
    local key_size="${3:-4096}"
    
    local key_file="$KEYSTORE_DIR/${service_name}.key"
    local pub_file="$KEYSTORE_DIR/${service_name}.pub"
    
    case "$key_type" in
        "rsa")
            openssl genrsa -out "$key_file" "$key_size"
            openssl rsa -in "$key_file" -pubout -out "$pub_file"
            ;;
        "ecdsa")
            openssl ecparam -name secp384r1 -genkey -noout -out "$key_file"
            openssl ec -in "$key_file" -pubout -out "$pub_file"
            ;;
        "ed25519")
            openssl genpkey -algorithm Ed25519 -out "$key_file"
            openssl pkey -in "$key_file" -pubout -out "$pub_file"
            ;;
        *)
            echo "不支持的密钥类型: $key_type"
            exit 1
            ;;
    esac
    
    # 设置权限
    chmod 600 "$key_file"
    chmod 644 "$pub_file"
    
    echo "服务密钥已生成:"
    echo "私钥: $key_file"
    echo "公钥: $pub_file"
}

# 轮换密钥
rotate_key() {
    local service_name="$1"
    local key_file="$KEYSTORE_DIR/${service_name}.key"
    local pub_file="$KEYSTORE_DIR/${service_name}.pub"
    
    if [ -f "$key_file" ]; then
        # 备份旧密钥
        local timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$key_file" "$BACKUP_DIR/${service_name}_${timestamp}.key"
        cp "$pub_file" "$BACKUP_DIR/${service_name}_${timestamp}.pub"
        
        echo "旧密钥已备份到: $BACKUP_DIR"
    fi
    
    # 生成新密钥
    generate_service_key "$service_name"
    
    echo "密钥轮换完成: $service_name"
}

# 验证密钥对
verify_keypair() {
    local service_name="$1"
    local key_file="$KEYSTORE_DIR/${service_name}.key"
    local pub_file="$KEYSTORE_DIR/${service_name}.pub"
    
    if [ ! -f "$key_file" ] || [ ! -f "$pub_file" ]; then
        echo "密钥文件不存在"
        return 1
    fi
    
    # 生成测试数据
    local test_data="test message for key verification"
    local signature_file="/tmp/test_signature"
    local verified_file="/tmp/test_verified"
    
    # 签名和验证
    echo "$test_data" | openssl dgst -sha256 -sign "$key_file" > "$signature_file"
    
    if echo "$test_data" | openssl dgst -sha256 -verify "$pub_file" -signature "$signature_file"; then
        echo "密钥对验证成功: $service_name"
        rm -f "$signature_file" "$verified_file"
        return 0
    else
        echo "密钥对验证失败: $service_name"
        rm -f "$signature_file" "$verified_file"
        return 1
    fi
}

# 密钥备份
backup_keys() {
    local backup_file="$BACKUP_DIR/keystore_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar -czf "$backup_file" -C "$KEYSTORE_DIR" .
    
    # 加密备份
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$backup_file" \
        -out "${backup_file}.encrypted" \
        -pass pass:"$(cat security/master.key)"
    
    # 删除明文备份
    rm "$backup_file"
    
    echo "密钥备份完成: ${backup_file}.encrypted"
}

case "${1:-help}" in
    "generate")
        generate_service_key "$2" "${3:-rsa}" "${4:-4096}"
        ;;
    "rotate")
        rotate_key "$2"
        ;;
    "verify")
        verify_keypair "$2"
        ;;
    "backup")
        backup_keys
        ;;
    *)
        echo "用法: $0 {generate|rotate|verify|backup} [service_name] [key_type] [key_size]"
        echo ""
        echo "命令:"
        echo "  generate <name> [type] [size] - 生成服务密钥"
        echo "  rotate <name>                 - 轮换密钥"
        echo "  verify <name>                 - 验证密钥对"
        echo "  backup                        - 备份所有密钥"
        ;;
esac
```

## 安全监控和审计

### 安全事件监控

创建 `security/security-monitor.sh`:
```bash
#!/bin/bash
# 安全事件监控

set -euo pipefail

LOG_DIR="/var/log/security"
ALERT_LOG="$LOG_DIR/security-alerts.log"
THREAT_DB="security/threat-indicators.json"

mkdir -p "$LOG_DIR"

# 监控异常登录
monitor_auth_events() {
    echo "监控认证事件..."
    
    # 监控SSH登录失败
    journalctl -u ssh --since "1 hour ago" | grep "Failed password" | while read line; do
        local ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        local timestamp=$(echo "$line" | cut -d' ' -f1-3)
        
        echo "[$timestamp] SSH登录失败: $ip" >> "$ALERT_LOG"
        
        # 检查是否为已知威胁IP
        if check_threat_ip "$ip"; then
            send_alert "HIGH" "已知威胁IP尝试SSH登录: $ip"
        fi
    done
    
    # 监控Web认证失败
    nginx_log="/var/log/nginx/access.log"
    if [ -f "$nginx_log" ]; then
        tail -n 1000 "$nginx_log" | grep " 401 " | while read line; do
            local ip=$(echo "$line" | cut -d' ' -f1)
            local timestamp=$(echo "$line" | cut -d'[' -f2 | cut -d']' -f1)
            
            echo "[$timestamp] Web认证失败: $ip" >> "$ALERT_LOG"
        done
    fi
}

# 监控网络异常
monitor_network_events() {
    echo "监控网络事件..."
    
    # 监控端口扫描
    netstat -an | grep ":8088 " | grep SYN_RECV | wc -l | while read count; do
        if [ "$count" -gt 50 ]; then
            send_alert "MEDIUM" "检测到可能的端口扫描，SYN_RECV连接数: $count"
        fi
    done
    
    # 监控异常大量连接
    netstat -an | grep ":8088 " | grep ESTABLISHED | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -5 | while read count ip; do
        if [ "$count" -gt 20 ]; then
            echo "[$(date)] 异常连接数量: $ip ($count connections)" >> "$ALERT_LOG"
            send_alert "MEDIUM" "IP $ip 建立了 $count 个连接，可能存在异常"
        fi
    done
}

# 监控文件完整性
monitor_file_integrity() {
    echo "监控文件完整性..."
    
    local checksum_file="security/file-checksums.txt"
    local current_checksums="/tmp/current-checksums.txt"
    
    # 计算关键文件的校验和
    find config/ security/ -type f -name "*.yaml" -o -name "*.conf" -o -name "*.sh" | xargs sha256sum > "$current_checksums"
    
    if [ -f "$checksum_file" ]; then
        # 比较校验和
        if ! diff -q "$checksum_file" "$current_checksums" >/dev/null; then
            echo "[$(date)] 文件完整性检查失败" >> "$ALERT_LOG"
            send_alert "HIGH" "检测到关键文件被修改"
            
            # 显示差异
            diff "$checksum_file" "$current_checksums" >> "$ALERT_LOG"
        fi
    fi
    
    # 更新校验和
    cp "$current_checksums" "$checksum_file"
    rm "$current_checksums"
}

# 监控容器运行时
monitor_container_runtime() {
    echo "监控容器运行时..."
    
    # 检查容器是否以root运行
    docker ps --format "table {{.Names}}\t{{.Image}}" | tail -n +2 | while read name image; do
        local user=$(docker exec "$name" whoami 2>/dev/null || echo "unknown")
        if [ "$user" = "root" ]; then
            send_alert "HIGH" "容器 $name 以root用户运行"
        fi
    done
    
    # 检查容器资源使用
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}" | tail -n +2 | while read name cpu mem; do
        cpu_num=$(echo "$cpu" | sed 's/%//')
        mem_num=$(echo "$mem" | sed 's/%//')
        
        if [ "${cpu_num%.*}" -gt 80 ]; then
            send_alert "MEDIUM" "容器 $name CPU使用率过高: $cpu"
        fi
        
        if [ "${mem_num%.*}" -gt 80 ]; then
            send_alert "MEDIUM" "容器 $name 内存使用率过高: $mem"
        fi
    done
}

# 检查威胁IP
check_threat_ip() {
    local ip="$1"
    
    if [ -f "$THREAT_DB" ]; then
        if jq -e --arg ip "$ip" '.threat_ips[] | select(. == $ip)' "$THREAT_DB" >/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# 发送告警
send_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    # 记录到日志
    echo "[$timestamp] [$level] $message" >> "$ALERT_LOG"
    
    # 发送邮件告警 (如果配置了)
    if [ -n "${ALERT_EMAIL:-}" ]; then
        echo "$message" | mail -s "Security Alert [$level]" "$ALERT_EMAIL"
    fi
    
    # 发送到Slack (如果配置了)
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Security Alert [$level]: $message\"}" \
            "$SLACK_WEBHOOK"
    fi
    
    # 记录到syslog
    logger -p security.warn "Clash Docker Security Alert [$level]: $message"
}

# 生成安全报告
generate_security_report() {
    local report_file="$LOG_DIR/security-report-$(date +%Y%m%d).txt"
    
    {
        echo "=== 安全监控日报 ==="
        echo "日期: $(date)"
        echo ""
        
        echo "=== 告警摘要 ==="
        if [ -f "$ALERT_LOG" ]; then
            tail -n 100 "$ALERT_LOG" | grep "$(date +%Y-%m-%d)" | \
            awk '{print $3}' | sort | uniq -c | sort -nr
        else
            echo "无告警记录"
        fi
        echo ""
        
        echo "=== 认证失败统计 ==="
        grep "认证失败" "$ALERT_LOG" 2>/dev/null | grep "$(date +%Y-%m-%d)" | wc -l || echo "0"
        echo ""
        
        echo "=== 网络异常统计 ==="
        grep "异常连接" "$ALERT_LOG" 2>/dev/null | grep "$(date +%Y-%m-%d)" | wc -l || echo "0"
        echo ""
        
        echo "=== 容器状态 ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        echo "=== 系统资源使用 ==="
        df -h | grep -E "(/$|/app)"
        free -h
        uptime
        
    } > "$report_file"
    
    echo "安全报告已生成: $report_file"
}

# 主监控循环
main() {
    echo "启动安全监控 - $(date)"
    
    while true; do
        monitor_auth_events
        monitor_network_events
        monitor_file_integrity
        monitor_container_runtime
        
        # 每小时生成一次报告
        if [ "$(date +%M)" = "00" ]; then
            generate_security_report
        fi
        
        # 等待60秒
        sleep 60
    done
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
```

### 审计日志配置

创建 `security/audit-config.sh`:
```bash
#!/bin/bash
# 审计日志配置

set -euo pipefail

# 配置auditd规则
configure_auditd() {
    echo "配置auditd审计..."
    
    # 安装auditd
    if ! command -v auditctl >/dev/null; then
        apt update && apt install -y auditd
    fi
    
    # 配置审计规则
    cat > /etc/audit/rules.d/clash-docker.rules << EOF
# Clash Docker 审计规则

# 监控关键目录
-w /app/config -p wa -k clash-config-change
-w /app/security -p wa -k security-change
-w /etc/docker -p wa -k docker-config-change

# 监控关键文件
-w /etc/passwd -p wa -k user-change
-w /etc/shadow -p wa -k password-change
-w /etc/group -p wa -k group-change
-w /etc/sudoers -p wa -k sudo-change

# 监控网络配置
-w /etc/hosts -p wa -k network-config
-w /etc/iptables -p wa -k firewall-change

# 监控进程执行
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/docker -k docker-exec
-a always,exit -F arch=b64 -S execve -F path=/usr/local/bin/docker-compose -k compose-exec

# 监控文件权限变更
-a always,exit -F arch=b64 -S chmod -S fchmod -S chown -S fchown -k file-perm-change

# 监控网络连接
-a always,exit -F arch=b64 -S socket -S connect -S accept -k network-connect
EOF

    # 重启auditd
    systemctl restart auditd
    systemctl enable auditd
    
    echo "auditd配置完成"
}

# 配置rsyslog审计日志
configure_rsyslog() {
    echo "配置rsyslog审计日志..."
    
    cat > /etc/rsyslog.d/50-clash-docker.conf << EOF
# Clash Docker 日志配置

# 安全相关日志
auth,authpriv.*                 /var/log/auth.log
security.*                      /var/log/security.log

# Docker日志
daemon.info                     /var/log/docker.log

# 自定义应用日志
local0.*                        /var/log/clash-docker.log

# 远程日志 (可选)
# *.* @@logserver:514

# 日志轮转
\$ModLoad imfile
\$InputFileName /app/logs/clash.log
\$InputFileTag clash:
\$InputFileStateFile clash-log
\$InputFileSeverity info
\$InputFileFacility local0
\$InputRunFileMonitor
EOF

    # 重启rsyslog
    systemctl restart rsyslog
    
    echo "rsyslog配置完成"
}

# 配置logrotate
configure_logrotate() {
    echo "配置日志轮转..."
    
    cat > /etc/logrotate.d/clash-docker << EOF
/var/log/clash-docker.log
/var/log/security.log
/app/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /bin/kill -HUP \`cat /var/run/rsyslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}

/app/security/scan-results/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    echo "logrotate配置完成"
}

# 主配置流程
main() {
    echo "开始配置审计日志..."
    
    configure_auditd
    configure_rsyslog
    configure_logrotate
    
    echo "审计日志配置完成"
    echo "审计日志位置:"
    echo "  - 系统审计: /var/log/audit/audit.log"
    echo "  - 安全日志: /var/log/security.log"
    echo "  - 应用日志: /var/log/clash-docker.log"
    echo "  - 认证日志: /var/log/auth.log"
}

main "$@"
```

## 安全扫描和检测

### 漏洞扫描

创建 `security/vulnerability-scan.sh`:
```bash
#!/bin/bash
# 漏洞扫描脚本

set -euo pipefail

SCAN_DIR="security/scan-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SCAN_DIR"

# 网络漏洞扫描
network_vulnerability_scan() {
    echo "执行网络漏洞扫描..."
    
    local target="${1:-localhost}"
    local scan_file="$SCAN_DIR/network_vuln_$TIMESTAMP.txt"
    
    # 使用nmap进行基础扫描
    nmap -sV -sC --script vuln "$target" > "$scan_file" 2>&1
    
    echo "网络扫描完成: $scan_file"
}

# 应用漏洞扫描
application_vulnerability_scan() {
    echo "执行应用漏洞扫描..."
    
    local base_url="${1:-http://localhost:8088}"
    local scan_file="$SCAN_DIR/app_vuln_$TIMESTAMP.txt"
    
    {
        echo "=== 应用漏洞扫描报告 ==="
        echo "目标: $base_url"
        echo "时间: $(date)"
        echo ""
        
        # HTTP头安全检查
        echo "=== HTTP安全头检查 ==="
        curl -I "$base_url" 2>/dev/null | grep -E "(X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security|Content-Security-Policy)" || echo "缺少安全头"
        echo ""
        
        # SSL/TLS配置检查
        if [[ "$base_url" == https* ]]; then
            echo "=== SSL/TLS配置检查 ==="
            local domain=$(echo "$base_url" | sed 's|https://||' | cut -d'/' -f1)
            echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -text | grep -E "(Signature Algorithm|Public Key|Not After)"
            echo ""
        fi
        
        # 路径遍历测试
        echo "=== 路径遍历测试 ==="
        for path in "../etc/passwd" "..%2F..%2Fetc%2Fpasswd" "....//....//etc/passwd"; do
            response=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/$path")
            echo "路径: $path -> HTTP $response"
        done
        echo ""
        
        # SQL注入测试 (基础)
        echo "=== SQL注入测试 ==="
        for payload in "'" "1' OR '1'='1" "1; DROP TABLE users--"; do
            response=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/api/test?id=$payload")
            echo "Payload: $payload -> HTTP $response"
        done
        echo ""
        
        # XSS测试 (基础)
        echo "=== XSS测试 ==="
        for payload in "<script>alert('xss')</script>" "\"><script>alert('xss')</script>"; do
            response=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/?search=$payload")
            echo "Payload: $payload -> HTTP $response"
        done
        
    } > "$scan_file"
    
    echo "应用扫描完成: $scan_file"
}

# 配置安全检查
configuration_security_scan() {
    echo "执行配置安全检查..."
    
    local scan_file="$SCAN_DIR/config_security_$TIMESTAMP.txt"
    
    {
        echo "=== 配置安全检查报告 ==="
        echo "时间: $(date)"
        echo ""
        
        echo "=== Docker配置检查 ==="
        
        # 检查容器是否以root运行
        echo "检查容器用户:"
        docker ps --format "table {{.Names}}\t{{.Image}}" | tail -n +2 | while read name image; do
            user=$(docker exec "$name" whoami 2>/dev/null || echo "unknown")
            echo "  $name: $user"
        done
        echo ""
        
        # 检查端口绑定
        echo "检查端口绑定:"
        docker ps --format "table {{.Names}}\t{{.Ports}}" | tail -n +2
        echo ""
        
        # 检查挂载的目录权限
        echo "检查挂载目录权限:"
        ls -la config/ data/ logs/ 2>/dev/null || echo "目录不存在"
        echo ""
        
        echo "=== 文件权限检查 ==="
        
        # 检查敏感文件权限
        for file in .env security/htpasswd security/*.key; do
            if [ -f "$file" ]; then
                echo "  $(ls -la "$file")"
            fi
        done
        echo ""
        
        echo "=== 网络配置检查 ==="
        
        # 检查防火墙状态
        if command -v ufw >/dev/null; then
            echo "UFW状态:"
            ufw status
        elif command -v iptables >/dev/null; then
            echo "iptables规则数量:"
            iptables -L | wc -l
        fi
        echo ""
        
        # 检查开放端口
        echo "开放端口:"
        netstat -tlnp | grep LISTEN
        
    } > "$scan_file"
    
    echo "配置检查完成: $scan_file"
}

# 恶意软件检查
malware_scan() {
    echo "执行恶意软件检查..."
    
    local scan_file="$SCAN_DIR/malware_scan_$TIMESTAMP.txt"
    
    # 使用ClamAV扫描
    if command -v clamscan >/dev/null; then
        echo "使用ClamAV扫描..."
        clamscan -r --log="$scan_file" /app/ /etc/ /var/log/ 2>&1
    else
        echo "ClamAV未安装，执行基础文件检查..."
        
        {
            echo "=== 基础恶意软件检查 ==="
            echo "时间: $(date)"
            echo ""
            
            # 检查可疑文件
            echo "检查可疑文件扩展名:"
            find /app/ -type f \( -name "*.exe" -o -name "*.bat" -o -name "*.cmd" -o -name "*.scr" \) 2>/dev/null || echo "未发现可疑文件"
            echo ""
            
            # 检查隐藏文件
            echo "检查隐藏文件:"
            find /app/ -name ".*" -type f ! -name ".env*" ! -name ".git*" 2>/dev/null || echo "未发现异常隐藏文件"
            echo ""
            
            # 检查异常网络连接
            echo "检查异常网络连接:"
            netstat -an | grep ESTABLISHED | grep -v -E "(127.0.0.1|localhost|:22|:80|:443|:8088)" || echo "未发现异常连接"
            
        } > "$scan_file"
    fi
    
    echo "恶意软件检查完成: $scan_file"
}

# 生成综合安全报告
generate_security_report() {
    echo "生成综合安全报告..."
    
    local report_file="$SCAN_DIR/security_comprehensive_report_$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Clash Docker 安全扫描报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .high-risk { background-color: #ffebee; border-color: #f44336; }
        .medium-risk { background-color: #fff3e0; border-color: #ff9800; }
        .low-risk { background-color: #e8f5e8; border-color: #4caf50; }
        .info { background-color: #e3f2fd; border-color: #2196f3; }
        pre { background-color: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .risk-high { color: #d32f2f; font-weight: bold; }
        .risk-medium { color: #f57c00; font-weight: bold; }
        .risk-low { color: #388e3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 Clash Docker 安全扫描报告</h1>
        <p><strong>扫描时间:</strong> $(date)</p>
        <p><strong>扫描范围:</strong> 网络、应用、配置、恶意软件</p>
    </div>

    <div class="section info">
        <h2>📊 扫描摘要</h2>
        <ul>
            <li>网络漏洞扫描: <a href="network_vuln_$TIMESTAMP.txt">查看报告</a></li>
            <li>应用漏洞扫描: <a href="app_vuln_$TIMESTAMP.txt">查看报告</a></li>
            <li>配置安全检查: <a href="config_security_$TIMESTAMP.txt">查看报告</a></li>
            <li>恶意软件检查: <a href="malware_scan_$TIMESTAMP.txt">查看报告</a></li>
        </ul>
    </div>

    <div class="section high-risk">
        <h2>🚨 高风险发现</h2>
        <ul>
EOF

    # 检查高风险项目
    if grep -q "CVE-" "$SCAN_DIR"/network_vuln_$TIMESTAMP.txt 2>/dev/null; then
        echo "            <li class=\"risk-high\">发现已知CVE漏洞</li>" >> "$report_file"
    fi
    
    if grep -q "root" "$SCAN_DIR"/config_security_$TIMESTAMP.txt 2>/dev/null; then
        echo "            <li class=\"risk-high\">发现以root用户运行的容器</li>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
        </ul>
    </div>

    <div class="section medium-risk">
        <h2>⚠️ 中风险发现</h2>
        <ul>
EOF

    # 检查中风险项目
    if ! grep -q "X-Frame-Options" "$SCAN_DIR"/app_vuln_$TIMESTAMP.txt 2>/dev/null; then
        echo "            <li class=\"risk-medium\">缺少安全响应头</li>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
        </ul>
    </div>

    <div class="section low-risk">
        <h2>ℹ️ 建议改进</h2>
        <ul>
            <li class="risk-low">定期更新依赖包</li>
            <li class="risk-low">加强日志监控</li>
            <li class="risk-low">实施定期安全扫描</li>
        </ul>
    </div>

    <div class="section info">
        <h2>📋 后续行动</h2>
        <ol>
            <li>立即修复所有高风险问题</li>
            <li>制定中风险问题的修复计划</li>
            <li>建立定期安全扫描机制</li>
            <li>更新安全策略和程序</li>
        </ol>
    </div>

    <div class="header">
        <p><strong>报告生成时间:</strong> $(date)</p>
        <p><strong>下次扫描建议:</strong> $(date -d '+1 week')</p>
    </div>
</body>
</html>
EOF

    echo "综合安全报告已生成: $report_file"
}

# 主扫描流程
main() {
    local target="${1:-localhost}"
    local base_url="${2:-http://localhost:8088}"
    
    echo "开始安全扫描 - $TIMESTAMP"
    echo "目标: $target"
    echo "应用URL: $base_url"
    echo ""
    
    network_vulnerability_scan "$target"
    application_vulnerability_scan "$base_url"
    configuration_security_scan
    malware_scan
    generate_security_report
    
    echo ""
    echo "安全扫描完成!"
    echo "扫描结果保存在: $SCAN_DIR"
    echo ""
    echo "建议立即查看并处理高风险问题。"
}

main "$@"
```

## 事件响应和恢复

### 安全事件响应流程

创建 `security/incident-response.sh`:
```bash
#!/bin/bash
# 安全事件响应脚本

set -euo pipefail

INCIDENT_DIR="security/incidents"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INCIDENT_ID="INC-$TIMESTAMP"

mkdir -p "$INCIDENT_DIR"

# 事件分类
declare -A INCIDENT_TYPES=(
    ["1"]="数据泄露"
    ["2"]="未授权访问"
    ["3"]="恶意软件感染"
    ["4"]="DDoS攻击"
    ["5"]="系统入侵"
    ["6"]="配置错误"
    ["7"]="其他安全事件"
)

# 严重性级别
declare -A SEVERITY_LEVELS=(
    ["1"]="低风险"
    ["2"]="中风险"
    ["3"]="高风险"
    ["4"]="严重"
)

# 创建事件报告
create_incident_report() {
    local incident_type="$1"
    local severity="$2"
    local description="$3"
    
    local report_file="$INCIDENT_DIR/$INCIDENT_ID.md"
    
    cat > "$report_file" << EOF
# 安全事件报告

**事件ID**: $INCIDENT_ID
**报告时间**: $(date -Iseconds)
**事件类型**: ${INCIDENT_TYPES[$incident_type]}
**严重性级别**: ${SEVERITY_LEVELS[$severity]}

## 事件描述

$description

## 事件时间线

- **$(date -Iseconds)**: 事件被发现并报告

## 初步影响评估

- **影响系统**: 待评估
- **数据泄露**: 待评估
- **服务中断**: 待评估
- **用户影响**: 待评估

## 响应状态

- **状态**: 正在处理
- **响应团队**: 安全运维团队
- **预计解决时间**: 待评估

## 响应步骤

1. [ ] 初步调查
2. [ ] 影响评估
3. [ ] 遏制措施
4. [ ] 根因分析
5. [ ] 系统恢复
6. [ ] 事后分析

## 证据收集

### 系统日志
EOF

    echo "事件报告已创建: $report_file"
    echo "$report_file"
}

# 紧急响应措施
emergency_response() {
    local incident_id="$1"
    local action="$2"
    
    echo "执行紧急响应措施: $action"
    
    case "$action" in
        "isolate")
            isolate_system
            ;;
        "shutdown")
            emergency_shutdown
            ;;
        "block-ip")
            block_suspicious_ip "$3"
            ;;
        "backup")
            emergency_backup
            ;;
        "notify")
            notify_security_team "$incident_id"
            ;;
        *)
            echo "未知的响应措施: $action"
            return 1
            ;;
    esac
    
    # 记录响应动作
    echo "[$(date -Iseconds)] 执行响应措施: $action" >> "$INCIDENT_DIR/$incident_id.log"
}

# 隔离系统
isolate_system() {
    echo "隔离系统..."
    
    # 断开网络连接 (保留管理连接)
    iptables -I INPUT 1 -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
    iptables -I INPUT 2 -p tcp --dport 22 -s 172.16.0.0/12 -j ACCEPT
    iptables -I INPUT 3 -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT
    iptables -I INPUT 4 -j DROP
    
    # 停止对外服务
    docker compose stop nginx
    
    echo "系统已隔离，仅保留管理连接"
}

# 紧急关闭
emergency_shutdown() {
    echo "执行紧急关闭..."
    
    # 创建关闭日志
    echo "[$(date -Iseconds)] 紧急关闭开始" >> "$INCIDENT_DIR/emergency_shutdown.log"
    
    # 停止所有服务
    docker compose down
    
    # 断开网络
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -F
    
    echo "紧急关闭完成"
}

# 阻止可疑IP
block_suspicious_ip() {
    local ip="$1"
    
    echo "阻止可疑IP: $ip"
    
    # 添加防火墙规则
    iptables -I INPUT 1 -s "$ip" -j DROP
    
    # 记录到日志
    echo "[$(date -Iseconds)] 阻止IP: $ip" >> "$INCIDENT_DIR/blocked_ips.log"
    
    # 保存防火墙规则
    iptables-save > /etc/iptables/rules.v4
    
    echo "IP $ip 已被阻止"
}

# 紧急备份
emergency_backup() {
    echo "执行紧急备份..."
    
    local backup_file="$INCIDENT_DIR/emergency_backup_$TIMESTAMP.tar.gz"
    
    # 备份关键数据
    tar -czf "$backup_file" \
        config/ \
        data/ \
        logs/ \
        security/ \
        .env* \
        compose*.yml
    
    # 计算校验和
    sha256sum "$backup_file" > "$backup_file.sha256"
    
    echo "紧急备份完成: $backup_file"
}

# 通知安全团队
notify_security_team() {
    local incident_id="$1"
    
    echo "通知安全团队..."
    
    # 发送邮件通知
    if [ -n "${SECURITY_EMAIL:-}" ]; then
        cat << EOF | mail -s "🚨 安全事件报告 - $incident_id" "$SECURITY_EMAIL"
安全事件报告

事件ID: $incident_id
发生时间: $(date)
服务器: $(hostname)

请立即查看事件详情并采取必要措施。

事件详情: $INCIDENT_DIR/$incident_id.md

-- 
Clash Docker 安全监控系统
EOF
    fi
    
    # 发送Slack通知
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\": \"🚨 安全事件报告\",
                \"attachments\": [{
                    \"color\": \"danger\",
                    \"fields\": [{
                        \"title\": \"事件ID\",
                        \"value\": \"$incident_id\",
                        \"short\": true
                    }, {
                        \"title\": \"发生时间\",
                        \"value\": \"$(date)\",
                        \"short\": true
                    }, {
                        \"title\": \"服务器\",
                        \"value\": \"$(hostname)\",
                        \"short\": true
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK"
    fi
    
    echo "安全团队通知已发送"
}

# 收集数字证据
collect_evidence() {
    local incident_id="$1"
    local evidence_dir="$INCIDENT_DIR/$incident_id-evidence"
    
    mkdir -p "$evidence_dir"
    
    echo "收集数字证据..."
    
    # 系统信息
    {
        echo "=== 系统信息 ==="
        uname -a
        uptime
        date
        echo ""
        
        echo "=== 网络连接 ==="
        netstat -an
        echo ""
        
        echo "=== 进程列表 ==="
        ps aux
        echo ""
        
        echo "=== 登录会话 ==="
        who
        last -n 20
        echo ""
        
    } > "$evidence_dir/system_info.txt"
    
    # 容器状态
    docker ps -a > "$evidence_dir/container_status.txt"
    docker logs clash > "$evidence_dir/clash_logs.txt" 2>&1
    docker logs nginx > "$evidence_dir/nginx_logs.txt" 2>&1
    
    # 网络配置
    ip addr show > "$evidence_dir/network_config.txt"
    iptables -L -n > "$evidence_dir/firewall_rules.txt"
    
    # 日志文件
    cp -r logs/ "$evidence_dir/application_logs/" 2>/dev/null || true
    cp /var/log/auth.log "$evidence_dir/" 2>/dev/null || true
    cp /var/log/syslog "$evidence_dir/" 2>/dev/null || true
    
    # 配置文件快照
    cp -r config/ "$evidence_dir/config_snapshot/" 2>/dev/null || true
    
    # 计算证据完整性
    find "$evidence_dir" -type f -exec sha256sum {} \; > "$evidence_dir/evidence_checksums.txt"
    
    echo "数字证据收集完成: $evidence_dir"
}

# 恢复系统
recover_system() {
    local incident_id="$1"
    local recovery_plan="$2"
    
    echo "开始系统恢复..."
    
    case "$recovery_plan" in
        "restart")
            echo "重启服务..."
            docker compose up -d
            ;;
        "restore")
            echo "从备份恢复..."
            local backup_file=$(ls -t "$INCIDENT_DIR"/emergency_backup_*.tar.gz | head -1)
            if [ -n "$backup_file" ]; then
                tar -xzf "$backup_file"
                docker compose up -d
            fi
            ;;
        "rebuild")
            echo "重建系统..."
            docker compose down
            docker system prune -f
            docker compose build --no-cache
            docker compose up -d
            ;;
        "manual")
            echo "需要手动恢复，请参考恢复程序文档"
            ;;
        *)
            echo "未知的恢复计划: $recovery_plan"
            return 1
            ;;
    esac
    
    # 验证恢复
    sleep 30
    if ./scripts/health-check.sh; then
        echo "系统恢复成功"
        echo "[$(date -Iseconds)] 系统恢复成功" >> "$INCIDENT_DIR/$incident_id.log"
    else
        echo "系统恢复失败，需要进一步处理"
        echo "[$(date -Iseconds)] 系统恢复失败" >> "$INCIDENT_DIR/$incident_id.log"
        return 1
    fi
}

# 事后分析
post_incident_analysis() {
    local incident_id="$1"
    
    echo "开始事后分析..."
    
    local analysis_file="$INCIDENT_DIR/$incident_id-analysis.md"
    
    cat > "$analysis_file" << EOF
# 事后分析报告

**事件ID**: $incident_id
**分析时间**: $(date -Iseconds)

## 事件总结

### 事件时间线
[填写详细的事件发生和响应时间线]

### 根本原因
[分析事件的根本原因]

### 影响评估
[评估事件对系统、数据和用户的影响]

## 响应效果评估

### 响应时间
- 发现时间: 
- 响应时间: 
- 解决时间: 

### 响应措施有效性
[评估各项响应措施的有效性]

## 改进建议

### 技术改进
1. [技术层面的改进建议]

### 流程改进
1. [流程层面的改进建议]

### 培训需求
1. [团队培训需求]

## 后续行动计划

- [ ] 实施技术改进
- [ ] 更新安全策略
- [ ] 进行团队培训
- [ ] 更新应急响应程序

## 经验教训

[总结此次事件的经验教训]

---
**分析人员**: 安全运维团队
**复核人员**: 
**批准人员**: 
EOF

    echo "事后分析报告模板已创建: $analysis_file"
}

# 交互式事件报告
interactive_incident_report() {
    echo "=== 安全事件报告系统 ==="
    echo ""
    
    # 选择事件类型
    echo "请选择事件类型:"
    for key in "${!INCIDENT_TYPES[@]}"; do
        echo "  $key. ${INCIDENT_TYPES[$key]}"
    done
    read -p "输入选择 (1-7): " incident_type
    
    if [[ ! "${INCIDENT_TYPES[$incident_type]:-}" ]]; then
        echo "无效的事件类型"
        exit 1
    fi
    
    # 选择严重性级别
    echo ""
    echo "请选择严重性级别:"
    for key in "${!SEVERITY_LEVELS[@]}"; do
        echo "  $key. ${SEVERITY_LEVELS[$key]}"
    done
    read -p "输入选择 (1-4): " severity
    
    if [[ ! "${SEVERITY_LEVELS[$severity]:-}" ]]; then
        echo "无效的严重性级别"
        exit 1
    fi
    
    # 输入事件描述
    echo ""
    echo "请描述事件详情:"
    read -p "描述: " description
    
    # 创建事件报告
    local report_file=$(create_incident_report "$incident_type" "$severity" "$description")
    
    echo ""
    echo "事件已记录: $INCIDENT_ID"
    echo "报告文件: $report_file"
    
    # 询问是否需要立即响应
    echo ""
    read -p "是否需要立即执行响应措施? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "可用的响应措施:"
        echo "  1. isolate - 隔离系统"
        echo "  2. shutdown - 紧急关闭"
        echo "  3. block-ip - 阻止IP"
        echo "  4. backup - 紧急备份"
        echo "  5. notify - 通知团队"
        
        read -p "选择响应措施: " response_action
        
        case "$response_action" in
            "1"|"isolate")
                emergency_response "$INCIDENT_ID" "isolate"
                ;;
            "2"|"shutdown")
                emergency_response "$INCIDENT_ID" "shutdown"
                ;;
            "3"|"block-ip")
                read -p "输入要阻止的IP: " suspicious_ip
                emergency_response "$INCIDENT_ID" "block-ip" "$suspicious_ip"
                ;;
            "4"|"backup")
                emergency_response "$INCIDENT_ID" "backup"
                ;;
            "5"|"notify")
                emergency_response "$INCIDENT_ID" "notify"
                ;;
            *)
                echo "无效的响应措施"
                ;;
        esac
    fi
    
    # 询问是否收集证据
    echo ""
    read -p "是否立即收集数字证据? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        collect_evidence "$INCIDENT_ID"
    fi
}

# 主程序
main() {
    local action="${1:-interactive}"
    
    case "$action" in
        "interactive"|"report")
            interactive_incident_report
            ;;
        "emergency")
            emergency_response "$2" "$3" "$4"
            ;;
        "collect")
            collect_evidence "$2"
            ;;
        "recover")
            recover_system "$2" "$3"
            ;;
        "analyze")
            post_incident_analysis "$2"
            ;;
        *)
            echo "用法: $0 {interactive|emergency|collect|recover|analyze} [参数...]"
            echo ""
            echo "命令:"
            echo "  interactive                           - 交互式事件报告"
            echo "  emergency <incident_id> <action>     - 紧急响应"
            echo "  collect <incident_id>                - 收集证据"
            echo "  recover <incident_id> <plan>         - 系统恢复"
            echo "  analyze <incident_id>                - 事后分析"
            ;;
    esac
}

main "$@"
```

## 安全最佳实践

### 定期安全维护

创建 `security/security-maintenance.sh`:
```bash
#!/bin/bash
# 定期安全维护脚本

set -euo pipefail

MAINTENANCE_LOG="security/maintenance.log"

log_maintenance() {
    echo "[$(date -Iseconds)] $*" | tee -a "$MAINTENANCE_LOG"
}

# 每日安全维护
daily_maintenance() {
    log_maintenance "开始每日安全维护"
    
    # 更新威胁情报
    update_threat_intelligence
    
    # 检查安全更新
    check_security_updates
    
    # 轮换临时密钥
    rotate_temporary_keys
    
    # 清理过期日志
    cleanup_expired_logs
    
    log_maintenance "每日安全维护完成"
}

# 每周安全维护
weekly_maintenance() {
    log_maintenance "开始每周安全维护"
    
    # 安全扫描
    ./security/vulnerability-scan.sh
    
    # 更新安全规则
    update_security_rules
    
    # 密钥健康检查
    verify_key_health
    
    # 生成安全报告
    generate_weekly_security_report
    
    log_maintenance "每周安全维护完成"
}

# 每月安全维护
monthly_maintenance() {
    log_maintenance "开始每月安全维护"
    
    # 密钥轮换
    ./security/key-management.sh rotate clash-service
    
    # 证书检查
    check_certificate_expiry
    
    # 安全策略审查
    review_security_policies
    
    # 安全培训评估
    assess_security_training
    
    log_maintenance "每月安全维护完成"
}

# 更新威胁情报
update_threat_intelligence() {
    log_maintenance "更新威胁情报"
    
    local threat_db="security/threat-indicators.json"
    local temp_file="/tmp/threat_update.json"
    
    # 从威胁情报源获取最新数据
    # 这里使用示例源，实际应替换为真实的威胁情报API
    if curl -s "https://example-threat-intel.com/api/latest" > "$temp_file"; then
        if jq empty "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$threat_db"
            log_maintenance "威胁情报更新成功"
        else
            log_maintenance "威胁情报格式无效"
        fi
    else
        log_maintenance "威胁情报获取失败"
    fi
}

# 检查安全更新
check_security_updates() {
    log_maintenance "检查安全更新"
    
    # 检查系统更新
    if command -v apt >/dev/null; then
        apt list --upgradable 2>/dev/null | grep -i security || log_maintenance "无安全更新"
    elif command -v yum >/dev/null; then
        yum check-update --security || log_maintenance "无安全更新"
    fi
    
    # 检查Docker镜像更新
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | grep -E "(clash|nginx)" | while read repo tag created; do
        # 检查镜像是否有新版本
        latest_tag=$(docker search "$repo" --limit 1 --format "{{.Name}}" 2>/dev/null | head -1)
        if [ -n "$latest_tag" ]; then
            log_maintenance "检查镜像更新: $repo:$tag"
        fi
    done
}

# 轮换临时密钥
rotate_temporary_keys() {
    log_maintenance "轮换临时密钥"
    
    # 生成新的会话密钥
    local session_key=$(openssl rand -hex 32)
    echo "$session_key" > security/session.key
    chmod 600 security/session.key
    
    # 更新API密钥 (如果需要)
    local current_hour=$(date +%H)
    if [ "$current_hour" = "00" ]; then
        ./security/api-key-auth.sh generate "daily-$(date +%Y%m%d)"
    fi
}

# 清理过期日志
cleanup_expired_logs() {
    log_maintenance "清理过期日志"
    
    # 清理超过30天的日志
    find logs/ -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find security/scan-results/ -name "*.txt" -mtime +7 -delete 2>/dev/null || true
    find security/incidents/ -name "*.log" -mtime +90 -delete 2>/dev/null || true
    
    log_maintenance "过期日志清理完成"
}

# 更新安全规则
update_security_rules() {
    log_maintenance "更新安全规则"
    
    # 更新防火墙规则
    ./security/firewall-rules.sh
    
    # 更新Nginx安全配置
    nginx -t && nginx -s reload || log_maintenance "Nginx配置验证失败"
    
    log_maintenance "安全规则更新完成"
}

# 验证密钥健康
verify_key_health() {
    log_maintenance "验证密钥健康"
    
    local keystore_dir="security/keystore"
    if [ -d "$keystore_dir" ]; then
        for key_file in "$keystore_dir"/*.key; do
            if [ -f "$key_file" ]; then
                local service_name=$(basename "$key_file" .key)
                if ./security/key-management.sh verify "$service_name"; then
                    log_maintenance "密钥健康: $service_name ✓"
                else
                    log_maintenance "密钥异常: $service_name ✗"
                fi
            fi
        done
    fi
}

# 检查证书过期
check_certificate_expiry() {
    log_maintenance "检查证书过期"
    
    local cert_dir="security/certs"
    if [ -d "$cert_dir" ]; then
        for cert_file in "$cert_dir"/*.crt; do
            if [ -f "$cert_file" ]; then
                local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
                local expiry_epoch=$(date -d "$expiry_date" +%s)
                local current_epoch=$(date +%s)
                local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                if [ "$days_left" -lt 30 ]; then
                    log_maintenance "证书即将过期: $cert_file (剩余 $days_left 天)"
                else
                    log_maintenance "证书有效: $cert_file (剩余 $days_left 天)"
                fi
            fi
        done
    fi
}

# 生成每周安全报告
generate_weekly_security_report() {
    log_maintenance "生成每周安全报告"
    
    local report_file="security/weekly-report-$(date +%Y%W).md"
    
    cat > "$report_file" << EOF
# 每周安全报告

**报告周期**: $(date -d 'last monday' +%Y-%m-%d) 至 $(date +%Y-%m-%d)
**生成时间**: $(date -Iseconds)

## 安全事件统计

### 安全告警
$(grep -c "Security Alert" security/security-alerts.log 2>/dev/null || echo "0") 条

### 认证失败
$(grep -c "认证失败" security/security-alerts.log 2>/dev/null || echo "0") 次

### 网络异常
$(grep -c "异常连接" security/security-alerts.log 2>/dev/null || echo "0") 次

## 漏洞扫描结果

### 发现的漏洞
$(find security/scan-results/ -name "*vuln*" -mtime -7 | wc -l) 个扫描文件

### 高风险问题
待手动分析

## 系统安全状态

### 容器安全
- 非root运行: $(docker ps --format "{{.Names}}" | xargs -I {} docker exec {} whoami | grep -v root | wc -l) / $(docker ps -q | wc -l)
- 资源限制: 已配置

### 网络安全
- 防火墙状态: $(ufw status | head -1)
- 开放端口: $(netstat -tlnp | grep LISTEN | wc -l)

## 改进建议

1. 定期更新系统和依赖
2. 加强日志监控
3. 实施更频繁的安全扫描

---
**报告生成**: 自动化安全维护系统
EOF

    log_maintenance "每周安全报告已生成: $report_file"
}

# 主维护流程
main() {
    local maintenance_type="${1:-daily}"
    
    case "$maintenance_type" in
        "daily")
            daily_maintenance
            ;;
        "weekly")
            weekly_maintenance
            ;;
        "monthly")
            monthly_maintenance
            ;;
        "all")
            daily_maintenance
            weekly_maintenance
            monthly_maintenance
            ;;
        *)
            echo "用法: $0 {daily|weekly|monthly|all}"
            echo ""
            echo "维护类型:"
            echo "  daily   - 每日安全维护"
            echo "  weekly  - 每周安全维护"
            echo "  monthly - 每月安全维护"
            echo "  all     - 执行所有维护任务"
            ;;
    esac
}

main "$@"
```

### 安全检查清单

创建 `security/security-checklist.md`:
```markdown
# 🔐 安全检查清单

## 部署前安全检查

### 容器安全
- [ ] 使用非root用户运行容器
- [ ] 配置只读根文件系统
- [ ] 移除不必要的Linux capabilities
- [ ] 设置资源限制 (CPU/内存)
- [ ] 启用安全选项 (no-new-privileges)
- [ ] 配置健康检查
- [ ] 使用最新的基础镜像

### 网络安全
- [ ] 配置防火墙规则
- [ ] 限制端口绑定 (仅localhost)
- [ ] 配置网络隔离
- [ ] 启用DDoS防护
- [ ] 配置SSL/TLS
- [ ] 设置安全响应头

### 访问控制
- [ ] 启用HTTP基本认证
- [ ] 配置IP白名单
- [ ] 设置API密钥认证
- [ ] 配置会话超时
- [ ] 实施最小权限原则

### 数据保护
- [ ] 加密敏感配置文件
- [ ] 安全存储密钥
- [ ] 配置数据备份
- [ ] 设置日志轮转
- [ ] 实施数据分类

## 运行时安全检查

### 监控和告警
- [ ] 配置安全事件监控
- [ ] 设置异常行为告警
- [ ] 启用审计日志
- [ ] 配置日志聚合
- [ ] 设置告警通知

### 漏洞管理
- [ ] 定期安全扫描
- [ ] 监控安全公告
- [ ] 及时应用补丁
- [ ] 验证修复效果
- [ ] 更新威胁情报

### 事件响应
- [ ] 制定响应流程
- [ ] 准备应急工具
- [ ] 定期演练
- [ ] 建立通信机制
- [ ] 准备恢复计划

## 定期维护检查

### 每日检查
- [ ] 查看安全告警
- [ ] 检查系统日志
- [ ] 验证服务状态
- [ ] 更新威胁情报
- [ ] 轮换临时密钥

### 每周检查
- [ ] 执行安全扫描
- [ ] 审查访问日志
- [ ] 更新安全规则
- [ ] 生成安全报告
- [ ] 验证备份完整性

### 每月检查
- [ ] 轮换长期密钥
- [ ] 检查证书过期
- [ ] 审查安全策略
- [ ] 更新安全文档
- [ ] 进行安全培训

## 合规性检查

### 数据保护
- [ ] 个人信息加密
- [ ] 数据最小化原则
- [ ] 访问日志记录
- [ ] 数据保留策略
- [ ] 删除确认机制

### 审计要求
- [ ] 完整的审计跟踪
- [ ] 不可篡改的日志
- [ ] 定期审计报告
- [ ] 第三方评估
- [ ] 合规性证明

### 风险管理
- [ ] 风险评估报告
- [ ] 威胁模型分析
- [ ] 业务影响分析
- [ ] 应急响应计划
- [ ] 持续改进机制
```

**重要提醒**: 
- 安全是一个持续的过程，需要定期评估和改进
- 所有安全措施都应该根据实际威胁环境进行调整
- 建议定期进行安全审计和渗透测试
- 保持对最新安全威胁和防护技术的关注

---

**更新日期**: 2025-07-13  
**文档版本**: v1.0.0  
**维护者**: 安全团队