# 🚀 生产环境部署指南

## 📚 目录

1. [部署架构概述](#部署架构概述)
2. [环境准备](#环境准备)
3. [安全加固部署](#安全加固部署)
4. [高可用部署](#高可用部署)
5. [负载均衡配置](#负载均衡配置)
6. [监控和日志](#监控和日志)
7. [备份恢复策略](#备份恢复策略)
8. [性能调优](#性能调优)
9. [运维操作](#运维操作)
10. [故障排除](#故障排除)

---

## 部署架构概述

### 单节点部署架构

```
┌─────────────────────────────────────┐
│           Load Balancer             │
│          (Optional: nginx)          │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         Docker Host                 │
│  ┌─────────────┬─────────────────┐  │
│  │    Clash    │     Nginx       │  │
│  │   Service   │    Service      │  │
│  └─────────────┴─────────────────┘  │
│  ┌─────────────┬─────────────────┐  │
│  │  Monitoring │     Logging     │  │
│  │ (Optional)  │   (Optional)    │  │
│  └─────────────┴─────────────────┘  │
└─────────────────────────────────────┘
```

### 高可用部署架构

```
┌─────────────────────────────────────┐
│         Load Balancer (HAProxy)     │
│           + Health Checks           │
└─────┬─────────────────┬─────────────┘
      │                 │
┌─────▼─────┐     ┌─────▼─────┐
│  Node 1   │     │  Node 2   │
│  Primary  │     │  Backup   │
└───────────┘     └───────────┘
      │                 │
┌─────▼─────────────────▼─────┐
│    Shared Storage (NFS)     │
│  Config + Logs + Backups    │
└─────────────────────────────┘
```

## 环境准备

### 系统要求

#### 最低配置
- **CPU**: 2核心
- **内存**: 4GB RAM
- **存储**: 20GB SSD
- **网络**: 100Mbps带宽
- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+

#### 推荐配置
- **CPU**: 4核心以上
- **内存**: 8GB RAM以上
- **存储**: 50GB SSD以上
- **网络**: 1Gbps带宽
- **操作系统**: Ubuntu 22.04 LTS

### 软件依赖

```bash
# Docker Engine (推荐版本)
Docker Engine: 24.0+
Docker Compose: 2.20+

# 系统工具
curl >= 7.68
wget >= 1.20
jq >= 1.6
openssl >= 1.1.1
```

### 服务器初始化

```bash
#!/bin/bash
# scripts/server-setup.sh

set -euo pipefail

# 系统更新
update_system() {
    echo "更新系统软件包..."
    
    if command -v apt >/dev/null; then
        apt update && apt upgrade -y
        apt install -y curl wget jq openssl unzip
    elif command -v yum >/dev/null; then
        yum update -y
        yum install -y curl wget jq openssl unzip
    fi
}

# 安装Docker
install_docker() {
    echo "安装Docker..."
    
    if ! command -v docker >/dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        
        # 将当前用户添加到docker组
        usermod -aG docker "$USER"
        echo "请重新登录以使docker组权限生效"
    else
        echo "Docker已安装: $(docker --version)"
    fi
}

# 安装Docker Compose
install_docker_compose() {
    echo "安装Docker Compose..."
    
    local version="2.24.0"
    local arch=$(uname -m)
    local binary_url="https://github.com/docker/compose/releases/download/v${version}/docker-compose-linux-${arch}"
    
    curl -L "$binary_url" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    echo "Docker Compose安装完成: $(docker-compose --version)"
}

# 配置防火墙
configure_firewall() {
    echo "配置防火墙..."
    
    if command -v ufw >/dev/null; then
        # Ubuntu/Debian
        ufw --force enable
        ufw allow ssh
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 8088/tcp  # Nginx服务端口
        # 不开放Clash代理端口到外网
        ufw status
    elif command -v firewall-cmd >/dev/null; then
        # CentOS/RHEL
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=8088/tcp
        firewall-cmd --reload
    fi
}

# 优化系统参数
optimize_system() {
    echo "优化系统参数..."
    
    # 网络参数优化
    cat >> /etc/sysctl.conf << EOF
# 网络优化
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000

# 文件描述符限制
fs.file-max = 1000000
EOF
    
    # 用户限制
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
    
    sysctl -p
}

# 创建部署用户
create_deploy_user() {
    local username="clash-deploy"
    
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
        usermod -aG docker "$username"
        
        # 设置sudo权限
        echo "$username ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$username"
        
        echo "部署用户创建完成: $username"
    fi
}

# 主安装流程
main() {
    echo "开始服务器初始化..."
    
    update_system
    install_docker
    install_docker_compose
    configure_firewall
    optimize_system
    create_deploy_user
    
    echo "服务器初始化完成！"
    echo "请重新登录以使所有更改生效。"
}

main "$@"
```

## 安全加固部署

### 使用安全加固配置

```bash
# 使用安全配置文件部署
docker compose -f security/compose.secure.yml up -d
```

### 安全配置详解

#### compose.secure.yml 配置

```yaml
version: '3.8'

services:
  clash:
    build:
      context: .
      dockerfile: security/Dockerfile.clash
    restart: unless-stopped
    
    # 安全配置
    user: "1000:1000"  # 非root用户
    read_only: true    # 只读根文件系统
    tmpfs:
      - /tmp:noexec,nosuid,nodev,size=100m
    
    # 资源限制
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
    
    # 网络安全
    networks:
      - clash-internal
    
    # 端口绑定到localhost
    ports:
      - "127.0.0.1:7890:7890"
      - "127.0.0.1:7891:7891"
      - "127.0.0.1:9090:9090"
    
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090/version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Linux capabilities
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    
    # 安全选项
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
    
    volumes:
      - ./config:/app/config:ro
      - clash-data:/app/data
      - clash-logs:/app/logs

  nginx:
    build:
      context: .
      dockerfile: security/Dockerfile.nginx
    restart: unless-stopped
    
    # 安全配置
    user: "1001:1001"
    read_only: true
    tmpfs:
      - /var/cache/nginx:noexec,nosuid,nodev,size=50m
      - /var/run:noexec,nosuid,nodev,size=10m
    
    # 资源限制
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
    
    networks:
      - clash-internal
      - web-external
    
    ports:
      - "8088:8088"
    
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8088/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      - CHOWN
      - SETGID
      - SETUID
    
    security_opt:
      - no-new-privileges:true
    
    volumes:
      - ./security/nginx-security.conf:/etc/nginx/nginx.conf:ro
      - ./security/htpasswd:/etc/nginx/htpasswd:ro
      - ./html:/var/www/html:ro
      - nginx-logs:/var/log/nginx

networks:
  clash-internal:
    driver: bridge
    internal: true  # 内部网络
  web-external:
    driver: bridge

volumes:
  clash-data:
    driver: local
  clash-logs:
    driver: local
  nginx-logs:
    driver: local
```

### SSL/TLS 配置

#### 生成自签名证书

```bash
#!/bin/bash
# scripts/generate-ssl-cert.sh

DOMAIN="${1:-localhost}"
CERT_DIR="./security/certs"

mkdir -p "$CERT_DIR"

# 生成私钥
openssl genrsa -out "$CERT_DIR/server.key" 4096

# 生成证书请求
openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
    -subj "/C=CN/ST=State/L=City/O=Organization/CN=$DOMAIN"

# 生成自签名证书
openssl x509 -req -days 365 -in "$CERT_DIR/server.csr" \
    -signkey "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt"

# 设置权限
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"

echo "SSL证书生成完成:"
echo "私钥: $CERT_DIR/server.key"
echo "证书: $CERT_DIR/server.crt"
```

#### 使用Let's Encrypt证书

```bash
#!/bin/bash
# scripts/setup-letsencrypt.sh

DOMAIN="$1"
EMAIL="$2"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "用法: $0 <域名> <邮箱>"
    exit 1
fi

# 安装certbot
if ! command -v certbot >/dev/null; then
    apt update && apt install -y certbot python3-certbot-nginx
fi

# 获取证书
certbot certonly --standalone \
    --preferred-challenges http \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

# 复制证书到项目目录
CERT_DIR="./security/certs"
mkdir -p "$CERT_DIR"

cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/server.crt"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/server.key"

# 设置权限
chown root:docker "$CERT_DIR"/*
chmod 640 "$CERT_DIR"/*

echo "Let's Encrypt证书配置完成"
```

## 高可用部署

### HAProxy负载均衡配置

创建 `haproxy/haproxy.cfg`:
```
global
    daemon
    maxconn 4096
    log stdout local0
    
defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httplog
    option dontlognull
    option httpclose
    option httpchk
    
frontend clash_frontend
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    redirect scheme https if !{ ssl_fc }
    
    # 健康检查
    option httpchk GET /health
    
    # 负载均衡
    default_backend clash_backend
    
backend clash_backend
    balance roundrobin
    option httpchk GET /health HTTP/1.1\r\nHost:\ localhost
    
    # 服务器节点
    server node1 10.0.1.10:8088 check inter 10s rise 2 fall 3
    server node2 10.0.1.11:8088 check inter 10s rise 2 fall 3 backup
    
# 统计页面
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
```

### 共享存储配置

#### NFS服务器设置

```bash
#!/bin/bash
# scripts/setup-nfs-server.sh

# 安装NFS服务器
apt update && apt install -y nfs-kernel-server

# 创建共享目录
mkdir -p /nfs/clash/{config,logs,data}

# 设置权限
chown -R nobody:nogroup /nfs/clash
chmod -R 755 /nfs/clash

# 配置导出
cat > /etc/exports << EOF
/nfs/clash 10.0.1.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF

# 重启服务
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server

echo "NFS服务器配置完成"
echo "共享路径: /nfs/clash"
```

#### 客户端挂载

```bash
#!/bin/bash
# scripts/mount-nfs-client.sh

NFS_SERVER="10.0.1.100"
MOUNT_POINT="/app/shared"

# 安装NFS客户端
apt update && apt install -y nfs-common

# 创建挂载点
mkdir -p "$MOUNT_POINT"

# 挂载NFS
mount -t nfs "$NFS_SERVER:/nfs/clash" "$MOUNT_POINT"

# 添加到fstab实现开机自动挂载
echo "$NFS_SERVER:/nfs/clash $MOUNT_POINT nfs defaults 0 0" >> /etc/fstab

echo "NFS客户端配置完成"
```

### Keepalived高可用

创建 `keepalived/keepalived.conf`:
```
! Configuration File for keepalived

global_defs {
    router_id CLASH_HA
}

vrrp_script chk_clash {
    script "/usr/local/bin/check_clash.sh"
    interval 2
    weight -2
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state MASTER              # 主节点设置为MASTER，备节点设置为BACKUP
    interface eth0
    virtual_router_id 51
    priority 110              # 主节点优先级高，备节点设置为100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass your_password
    }
    virtual_ipaddress {
        10.0.1.100/24         # 虚拟IP
    }
    track_script {
        chk_clash
    }
}
```

健康检查脚本 `/usr/local/bin/check_clash.sh`:
```bash
#!/bin/bash
# Clash服务健康检查

# 检查Docker容器状态
if ! docker compose ps | grep -q "clash.*Up"; then
    exit 1
fi

# 检查Clash API响应
if ! curl -s -f http://localhost:9090/version >/dev/null; then
    exit 1
fi

# 检查配置服务
if ! curl -s -f http://localhost:8088/health >/dev/null; then
    exit 1
fi

exit 0
```

## 负载均衡配置

### Nginx负载均衡

创建 `nginx/upstream.conf`:
```nginx
upstream clash_backend {
    least_conn;
    
    server 10.0.1.10:8088 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:8088 max_fails=3 fail_timeout=30s backup;
    
    # 健康检查 (需要nginx-plus或第三方模块)
    # health_check uri=/health interval=10s;
}

upstream clash_api {
    least_conn;
    
    server 10.0.1.10:9090 max_fails=2 fail_timeout=10s;
    server 10.0.1.11:9090 max_fails=2 fail_timeout=10s backup;
}

server {
    listen 80;
    listen 443 ssl http2;
    server_name clash.yourdomain.com;
    
    # SSL配置
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    # 配置文件访问
    location /config.yaml {
        proxy_pass http://clash_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 缓存配置
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # API代理
    location /api/ {
        proxy_pass http://clash_api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 健康检查
    location /health {
        proxy_pass http://clash_backend;
        access_log off;
    }
    
    # 状态监控
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.1.0/24;
        deny all;
    }
}
```

## 监控和日志

### Prometheus + Grafana 监控

创建 `monitoring/docker-compose.monitoring.yml`:
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: clash-prometheus
    restart: unless-stopped
    
    ports:
      - "9091:9090"
    
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: clash-grafana
    restart: unless-stopped
    
    ports:
      - "3000:3000"
    
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources:ro
    
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: clash-node-exporter
    restart: unless-stopped
    
    ports:
      - "9100:9100"
    
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: clash-cadvisor
    restart: unless-stopped
    
    ports:
      - "8080:8080"
    
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    
    privileged: true
    devices:
      - /dev/kmsg
    
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  grafana-data:
```

### 日志聚合

使用ELK Stack进行日志聚合：

创建 `logging/docker-compose.logging.yml`:
```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
    container_name: clash-elasticsearch
    restart: unless-stopped
    
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    
    ports:
      - "9200:9200"
    
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    
    networks:
      - logging

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.0
    container_name: clash-logstash
    restart: unless-stopped
    
    volumes:
      - ./logging/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
      - /var/log:/var/log:ro
      - ./logs:/app/logs:ro
    
    depends_on:
      - elasticsearch
    
    networks:
      - logging

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.0
    container_name: clash-kibana
    restart: unless-stopped
    
    ports:
      - "5601:5601"
    
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    
    depends_on:
      - elasticsearch
    
    networks:
      - logging

networks:
  logging:
    driver: bridge

volumes:
  elasticsearch-data:
```

## 备份恢复策略

### 自动备份脚本

创建 `scripts/backup.sh`:
```bash
#!/bin/bash
# 自动备份脚本

set -euo pipefail

BACKUP_DIR="/app/backups"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份配置文件
backup_configs() {
    echo "备份配置文件..."
    
    local config_backup="$BACKUP_DIR/config_$TIMESTAMP.tar.gz"
    tar -czf "$config_backup" \
        --exclude='*.log' \
        --exclude='*.tmp' \
        config/ .env* compose*.yml
    
    echo "配置备份完成: $config_backup"
}

# 备份数据
backup_data() {
    echo "备份数据..."
    
    local data_backup="$BACKUP_DIR/data_$TIMESTAMP.tar.gz"
    tar -czf "$data_backup" data/ logs/
    
    echo "数据备份完成: $data_backup"
}

# 备份Docker镜像
backup_images() {
    echo "备份Docker镜像..."
    
    local images_backup="$BACKUP_DIR/images_$TIMESTAMP.tar"
    docker save $(docker compose config --images) -o "$images_backup"
    gzip "$images_backup"
    
    echo "镜像备份完成: ${images_backup}.gz"
}

# 清理旧备份
cleanup_old_backups() {
    echo "清理${RETENTION_DAYS}天前的备份..."
    
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
    
    echo "旧备份清理完成"
}

# 远程备份 (可选)
remote_backup() {
    local remote_server="${BACKUP_REMOTE_SERVER:-}"
    local remote_path="${BACKUP_REMOTE_PATH:-/backups/clash}"
    
    if [ -n "$remote_server" ]; then
        echo "同步到远程服务器: $remote_server"
        
        rsync -az --delete "$BACKUP_DIR/" "$remote_server:$remote_path/"
        
        echo "远程备份完成"
    fi
}

# 主备份流程
main() {
    echo "开始备份 - $TIMESTAMP"
    
    backup_configs
    backup_data
    backup_images
    cleanup_old_backups
    remote_backup
    
    echo "备份完成 - $TIMESTAMP"
}

main "$@"
```

### 恢复脚本

创建 `scripts/restore.sh`:
```bash
#!/bin/bash
# 恢复脚本

set -euo pipefail

BACKUP_FILE="$1"
RESTORE_TYPE="${2:-full}"  # full, config, data

if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

# 停止服务
stop_services() {
    echo "停止服务..."
    docker compose down
}

# 恢复配置
restore_config() {
    echo "恢复配置文件..."
    
    # 备份当前配置
    if [ -d "config" ]; then
        mv config "config.backup.$(date +%s)"
    fi
    
    # 解压备份文件
    tar -xzf "$BACKUP_FILE"
    
    echo "配置恢复完成"
}

# 恢复数据
restore_data() {
    echo "恢复数据..."
    
    # 备份当前数据
    if [ -d "data" ]; then
        mv data "data.backup.$(date +%s)"
    fi
    if [ -d "logs" ]; then
        mv logs "logs.backup.$(date +%s)"
    fi
    
    # 解压数据
    tar -xzf "$BACKUP_FILE"
    
    echo "数据恢复完成"
}

# 验证恢复
verify_restore() {
    echo "验证恢复..."
    
    # 检查配置文件
    if [ ! -f "config/config.yaml" ]; then
        echo "错误: 配置文件缺失"
        exit 1
    fi
    
    # 验证YAML语法
    if ! python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"; then
        echo "错误: 配置文件格式错误"
        exit 1
    fi
    
    echo "恢复验证通过"
}

# 启动服务
start_services() {
    echo "启动服务..."
    docker compose up -d
    
    # 等待服务启动
    sleep 30
    
    # 验证服务状态
    ./scripts/health-check.sh
}

# 主恢复流程
main() {
    echo "开始恢复 - $(date)"
    echo "备份文件: $BACKUP_FILE"
    echo "恢复类型: $RESTORE_TYPE"
    
    read -p "确认要恢复吗? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "恢复已取消"
        exit 0
    fi
    
    stop_services
    
    case "$RESTORE_TYPE" in
        "config")
            restore_config
            ;;
        "data")
            restore_data
            ;;
        "full"|*)
            restore_config
            restore_data
            ;;
    esac
    
    verify_restore
    start_services
    
    echo "恢复完成 - $(date)"
}

main "$@"
```

## 性能调优

### Docker优化

#### 容器资源限制

```yaml
# 优化后的服务配置
services:
  clash:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '1.0'
    
    # 优化的重启策略
    restart: unless-stopped
    
    # 内存和交换限制
    mem_swappiness: 10
    shm_size: 128m

  nginx:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
    
    # Nginx优化
    command: >
      nginx -g "daemon off;
      worker_processes auto;
      worker_connections 1024;"
```

### 系统优化

#### 内核参数调优

创建 `scripts/optimize-system.sh`:
```bash
#!/bin/bash
# 系统优化脚本

# 网络优化
cat >> /etc/sysctl.conf << EOF
# TCP优化
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 6000

# 连接追踪优化
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 300

# 内存优化
vm.swappiness = 10
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5

# 文件系统优化
fs.file-max = 1000000
fs.inotify.max_user_watches = 524288
EOF

sysctl -p
```

### 应用优化

#### Clash配置优化

```yaml
# 优化的Clash配置
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

# DNS优化
dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1
  fallback-filter:
    geoip: true
    ipcidr:
      - 240.0.0.0/4

# 实验性功能
experimental:
  sniff-tls-sni: true
  interface-name: eth0

# 连接优化
profile:
  store-selected: true
  store-fake-ip: true

# 规则优化 - 使用高效的规则顺序
rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```

## 运维操作

### 滚动更新

创建 `scripts/rolling-update.sh`:
```bash
#!/bin/bash
# 滚动更新脚本

set -euo pipefail

NEW_VERSION="$1"
HEALTH_CHECK_URL="http://localhost:8088/health"

if [ -z "$NEW_VERSION" ]; then
    echo "用法: $0 <新版本>"
    exit 1
fi

# 更新前检查
pre_update_check() {
    echo "更新前检查..."
    
    # 检查当前服务状态
    if ! curl -s -f "$HEALTH_CHECK_URL" >/dev/null; then
        echo "错误: 当前服务不健康，无法进行更新"
        exit 1
    fi
    
    # 备份当前配置
    ./scripts/backup.sh
    
    echo "更新前检查完成"
}

# 拉取新镜像
pull_images() {
    echo "拉取新镜像 $NEW_VERSION..."
    
    # 更新镜像标签
    sed -i "s/image: .*/image: clash-docker:$NEW_VERSION/" compose.yml
    
    # 拉取镜像
    docker compose pull
    
    echo "镜像拉取完成"
}

# 滚动更新
rolling_update() {
    echo "开始滚动更新..."
    
    # 更新配置生成器 (快速重启)
    docker compose up -d config-generator
    sleep 5
    
    # 更新Clash服务
    docker compose up -d clash
    sleep 30
    
    # 健康检查
    local attempts=0
    while [ $attempts -lt 12 ]; do
        if curl -s -f "$HEALTH_CHECK_URL" >/dev/null; then
            echo "Clash服务健康检查通过"
            break
        fi
        echo "等待Clash服务启动... ($((attempts + 1))/12)"
        sleep 10
        ((attempts++))
    done
    
    if [ $attempts -eq 12 ]; then
        echo "错误: Clash服务健康检查失败，回滚更新"
        rollback_update
        exit 1
    fi
    
    # 更新Nginx服务
    docker compose up -d nginx
    sleep 10
    
    echo "滚动更新完成"
}

# 回滚更新
rollback_update() {
    echo "开始回滚更新..."
    
    # 恢复之前的镜像
    docker compose down
    docker compose up -d
    
    echo "回滚完成"
}

# 更新后验证
post_update_verify() {
    echo "更新后验证..."
    
    # 完整健康检查
    ./scripts/health-check.sh
    
    # 功能测试
    if curl -s -f "$HEALTH_CHECK_URL" | grep -q "healthy"; then
        echo "服务验证通过"
    else
        echo "错误: 服务验证失败"
        return 1
    fi
    
    echo "更新验证完成"
}

# 清理旧镜像
cleanup_old_images() {
    echo "清理旧镜像..."
    
    docker image prune -f
    
    echo "镜像清理完成"
}

# 主更新流程
main() {
    echo "开始滚动更新到版本: $NEW_VERSION"
    
    pre_update_check
    pull_images
    rolling_update
    
    if post_update_verify; then
        cleanup_old_images
        echo "更新成功完成!"
    else
        rollback_update
        echo "更新失败，已回滚"
        exit 1
    fi
}

main "$@"
```

### 扩容缩容

创建 `scripts/scale.sh`:
```bash
#!/bin/bash
# 服务扩容缩容脚本

ACTION="$1"  # scale-up, scale-down
REPLICAS="${2:-2}"

scale_up() {
    echo "扩容服务到 $REPLICAS 个副本..."
    
    # 使用Docker Swarm模式扩容
    if docker info | grep -q "Swarm: active"; then
        docker service scale clash-docker_clash="$REPLICAS"
        docker service scale clash-docker_nginx="$REPLICAS"
    else
        echo "注意: 当前不在Swarm模式，使用Compose扩容"
        docker compose up -d --scale clash="$REPLICAS" --scale nginx="$REPLICAS"
    fi
    
    echo "扩容完成"
}

scale_down() {
    echo "缩容服务到 $REPLICAS 个副本..."
    
    if docker info | grep -q "Swarm: active"; then
        docker service scale clash-docker_clash="$REPLICAS"
        docker service scale clash-docker_nginx="$REPLICAS"
    else
        docker compose up -d --scale clash="$REPLICAS" --scale nginx="$REPLICAS"
    fi
    
    echo "缩容完成"
}

case "$ACTION" in
    "scale-up")
        scale_up
        ;;
    "scale-down")
        scale_down
        ;;
    *)
        echo "用法: $0 {scale-up|scale-down} [副本数]"
        exit 1
        ;;
esac
```

## 故障排除

### 常见生产环境问题

#### 1. 服务启动失败

```bash
# 诊断步骤
echo "=== 检查容器状态 ==="
docker compose ps -a

echo "=== 检查容器日志 ==="
docker compose logs --tail=50

echo "=== 检查系统资源 ==="
df -h
free -h
docker system df

echo "=== 检查网络 ==="
netstat -tlnp | grep -E ':(7890|7891|8088|9090)'
```

#### 2. 性能问题

```bash
# 性能诊断
echo "=== 容器资源使用 ==="
docker stats --no-stream

echo "=== 系统负载 ==="
uptime
iostat 1 3

echo "=== 网络连接数 ==="
ss -s
netstat -an | grep :7890 | wc -l
```

#### 3. 高可用故障

```bash
# HA诊断
echo "=== Keepalived状态 ==="
systemctl status keepalived

echo "=== VIP状态 ==="
ip addr show | grep -A 2 -B 2 "10.0.1.100"

echo "=== HAProxy状态 ==="
curl -s http://localhost:8404/stats
```

### 紧急恢复程序

创建 `scripts/emergency-recovery.sh`:
```bash
#!/bin/bash
# 紧急恢复脚本

set -euo pipefail

RECOVERY_MODE="$1"  # quick, full, failover

quick_recovery() {
    echo "执行快速恢复..."
    
    # 重启所有服务
    docker compose restart
    
    # 等待服务启动
    sleep 30
    
    # 健康检查
    ./scripts/health-check.sh
}

full_recovery() {
    echo "执行完整恢复..."
    
    # 停止所有服务
    docker compose down
    
    # 清理异常状态
    docker system prune -f
    
    # 从最新备份恢复
    local latest_backup=$(ls -t /app/backups/config_*.tar.gz | head -1)
    if [ -n "$latest_backup" ]; then
        ./scripts/restore.sh "$latest_backup" config
    fi
    
    # 重新启动
    docker compose up -d
    
    # 验证恢复
    sleep 60
    ./scripts/health-check.sh
}

failover_recovery() {
    echo "执行故障转移..."
    
    # 检查备用节点
    local backup_node="${BACKUP_NODE:-10.0.1.11}"
    
    if ping -c 3 "$backup_node" >/dev/null; then
        echo "切换到备用节点: $backup_node"
        
        # 在备用节点上启动服务
        ssh "$backup_node" "cd /app/clash-docker && docker compose up -d"
        
        # 更新DNS或负载均衡器配置
        # (具体实现取决于你的基础设施)
        
        echo "故障转移完成"
    else
        echo "错误: 备用节点不可达"
        exit 1
    fi
}

case "$RECOVERY_MODE" in
    "quick")
        quick_recovery
        ;;
    "full")
        full_recovery
        ;;
    "failover")
        failover_recovery
        ;;
    *)
        echo "用法: $0 {quick|full|failover}"
        echo "  quick    - 快速重启恢复"
        echo "  full     - 完整恢复流程"
        echo "  failover - 故障转移到备用节点"
        exit 1
        ;;
esac

echo "紧急恢复完成"
```

---

**更新日期**: 2025-07-13  
**版本**: v1.0.0  
**维护者**: Clash Docker Team

**生产环境部署checklist**:
- [ ] 服务器安全加固完成
- [ ] SSL/TLS证书配置
- [ ] 监控和告警设置
- [ ] 备份策略验证
- [ ] 灾难恢复预案测试
- [ ] 性能基准测试
- [ ] 文档和运维手册完善

---

**更新日期**: 2025-07-13  
**文档版本**: v1.0.0  
**维护者**: 部署运维团队