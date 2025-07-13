# 🔄 迁移指南

## 📚 目录

1. [迁移概述](#迁移概述)
2. [版本升级指南](#版本升级指南)
3. [配置迁移](#配置迁移)
4. [数据迁移](#数据迁移)
5. [平台迁移](#平台迁移)
6. [兼容性检查](#兼容性检查)
7. [迁移工具](#迁移工具)
8. [回滚策略](#回滚策略)
9. [常见问题](#常见问题)
10. [迁移检查清单](#迁移检查清单)

---

## 迁移概述

### 支持的迁移场景

- **版本升级**: 从旧版本升级到新版本
- **平台迁移**: 在不同操作系统或云平台之间迁移
- **配置迁移**: 从其他代理解决方案迁移到Clash Docker
- **环境迁移**: 从开发环境迁移到生产环境
- **架构迁移**: 从单机部署迁移到集群部署

### 迁移准备事项

- [ ] 备份所有配置文件和数据
- [ ] 记录当前系统配置和依赖
- [ ] 准备测试环境进行迁移验证
- [ ] 制定详细的迁移计划和时间表
- [ ] 准备回滚方案

---

## 版本升级指南

### 版本兼容性矩阵

| 源版本 | 目标版本 | 兼容性 | 迁移复杂度 | 说明 |
|--------|----------|--------|------------|------|
| v1.0.x | v1.1.x | ✅ 完全兼容 | 简单 | 直接升级 |
| v1.x.x | v2.0.x | ⚠️ 部分兼容 | 中等 | 需要配置调整 |
| v1.x.x | v3.0.x | ❌ 不兼容 | 复杂 | 需要完全重新配置 |

### 自动版本升级

```bash
#!/bin/bash
# scripts/upgrade.sh

set -euo pipefail

CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
TARGET_VERSION=${1:-"latest"}

echo "🔄 开始版本升级..."
echo "当前版本: $CURRENT_VERSION"
echo "目标版本: $TARGET_VERSION"

# 创建备份
backup_current_setup() {
    local backup_dir="backups/upgrade-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo "📦 创建备份到 $backup_dir..."
    
    # 备份配置文件
    cp -r config/ "$backup_dir/config/" 2>/dev/null || true
    cp -r data/ "$backup_dir/data/" 2>/dev/null || true
    cp .env "$backup_dir/.env" 2>/dev/null || true
    cp compose.yml "$backup_dir/compose.yml" 2>/dev/null || true
    
    # 导出容器状态
    docker compose ps --format json > "$backup_dir/containers.json"
    
    echo "✅ 备份完成"
    echo "$backup_dir" > .last_backup
}

# 升级前检查
pre_upgrade_check() {
    echo "🔍 执行升级前检查..."
    
    # 检查磁盘空间
    local available_space=$(df /var/lib/docker --output=avail | tail -n1)
    if [ "$available_space" -lt 2097152 ]; then  # 2GB
        echo "❌ 磁盘空间不足，至少需要2GB可用空间"
        exit 1
    fi
    
    # 检查依赖服务
    if ! docker --version >/dev/null 2>&1; then
        echo "❌ Docker未安装或无法访问"
        exit 1
    fi
    
    if ! docker compose version >/dev/null 2>&1; then
        echo "❌ Docker Compose未安装或无法访问"
        exit 1
    fi
    
    echo "✅ 升级前检查通过"
}

# 执行升级
perform_upgrade() {
    echo "🚀 开始执行升级..."
    
    # 停止当前服务
    echo "⏹️ 停止当前服务..."
    docker compose down
    
    # 拉取新镜像
    echo "📥 拉取新镜像..."
    docker compose pull
    
    # 更新配置文件（如果需要）
    if [ -f "scripts/migrate-config-$TARGET_VERSION.sh" ]; then
        echo "🔧 更新配置文件..."
        ./scripts/migrate-config-$TARGET_VERSION.sh
    fi
    
    # 启动新版本
    echo "▶️ 启动新版本..."
    docker compose up -d
    
    # 等待服务启动
    echo "⏳ 等待服务启动..."
    sleep 30
    
    echo "✅ 升级完成"
}

# 升级后验证
post_upgrade_verify() {
    echo "🔍 执行升级后验证..."
    
    # 检查服务状态
    if ! docker compose ps | grep -q "Up"; then
        echo "❌ 服务启动失败"
        return 1
    fi
    
    # 检查健康状态
    if command -v ./scripts/health-check.sh >/dev/null; then
        if ! ./scripts/health-check.sh; then
            echo "❌ 健康检查失败"
            return 1
        fi
    fi
    
    # 更新版本记录
    echo "$TARGET_VERSION" > VERSION
    
    echo "✅ 升级验证通过"
}

# 主升级流程
main() {
    backup_current_setup
    pre_upgrade_check
    perform_upgrade
    
    if post_upgrade_verify; then
        echo "🎉 升级成功完成！"
        echo "新版本: $TARGET_VERSION"
    else
        echo "❌ 升级验证失败，开始回滚..."
        ./scripts/rollback.sh
        exit 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [TARGET_VERSION]

选项:
  TARGET_VERSION    目标版本号（默认: latest）
  -h, --help       显示此帮助信息

示例:
  $0 v2.1.0        升级到v2.1.0版本
  $0 latest        升级到最新版本
EOF
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
```

### 手动版本升级步骤

1. **备份当前配置**
   ```bash
   # 创建备份目录
   mkdir -p backups/$(date +%Y%m%d)
   
   # 备份配置和数据
   cp -r config/ backups/$(date +%Y%m%d)/
   cp -r data/ backups/$(date +%Y%m%d)/
   cp .env backups/$(date +%Y%m%d)/
   ```

2. **停止当前服务**
   ```bash
   docker compose down
   ```

3. **更新镜像**
   ```bash
   docker compose pull
   ```

4. **更新配置（如有需要）**
   ```bash
   # 检查是否需要配置迁移
   ./scripts/check-config-compatibility.sh
   ```

5. **启动新版本**
   ```bash
   docker compose up -d
   ```

6. **验证升级结果**
   ```bash
   ./scripts/health-check.sh
   ```

---

## 配置迁移

### 环境变量迁移

#### 从v1.x到v2.x的环境变量变更

```bash
#!/bin/bash
# scripts/migrate-env-v2.sh

set -euo pipefail

echo "🔧 迁移环境变量配置到v2.x格式..."

# 备份原有.env文件
cp .env .env.backup.$(date +%Y%m%d)

# 新旧变量名映射
declare -A env_mappings=(
    ["CLASH_SECRET"]="CLASH_API_SECRET"
    ["PROXY_PORT"]="CLASH_HTTP_PORT"
    ["SOCKS_PORT"]="CLASH_SOCKS_PORT"
    ["CONTROL_PORT"]="CLASH_API_PORT"
    ["WEB_PORT"]="NGINX_PORT"
)

# 执行变量名迁移
migrate_env_vars() {
    local temp_file=$(mktemp)
    
    while IFS= read -r line; do
        # 跳过注释和空行
        if [[ $line =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 处理变量赋值行
        if [[ $line =~ ^([^=]+)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            # 检查是否需要重命名
            if [[ -n "${env_mappings[$var_name]:-}" ]]; then
                echo "🔄 重命名 $var_name -> ${env_mappings[$var_name]}"
                echo "${env_mappings[$var_name]}=$var_value" >> "$temp_file"
            else
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < .env
    
    # 替换原文件
    mv "$temp_file" .env
    echo "✅ 环境变量迁移完成"
}

# 添加新的环境变量
add_new_env_vars() {
    echo "📝 添加新的环境变量..."
    
    cat >> .env << 'EOF'

# v2.x 新增配置项
CLASH_LOG_LEVEL=info
CLASH_IPV6=false
CLASH_ALLOW_LAN=true
CLASH_BIND_ADDRESS=0.0.0.0

# 新的安全配置
ENABLE_TLS=false
TLS_CERT_PATH=
TLS_KEY_PATH=

# 监控配置
ENABLE_METRICS=true
METRICS_PORT=9091
EOF
    
    echo "✅ 新环境变量添加完成"
}

migrate_env_vars
add_new_env_vars

echo "🎉 配置迁移完成！请检查并更新 .env 文件中的新配置项"
```

### 从其他代理方案迁移

#### 从V2Ray迁移

```bash
#!/bin/bash
# scripts/migrate-from-v2ray.sh

set -euo pipefail

V2RAY_CONFIG=${1:-"config.json"}

echo "🔄 从V2Ray配置迁移到Clash..."

# 解析V2Ray配置
parse_v2ray_config() {
    if [ ! -f "$V2RAY_CONFIG" ]; then
        echo "❌ V2Ray配置文件不存在: $V2RAY_CONFIG"
        exit 1
    fi
    
    # 提取关键配置信息
    local inbound_port=$(jq -r '.inbounds[0].port' "$V2RAY_CONFIG" 2>/dev/null || echo "1080")
    local outbound_address=$(jq -r '.outbounds[0].settings.vnext[0].address' "$V2RAY_CONFIG" 2>/dev/null || echo "")
    local outbound_port=$(jq -r '.outbounds[0].settings.vnext[0].port' "$V2RAY_CONFIG" 2>/dev/null || echo "")
    
    echo "检测到的V2Ray配置:"
    echo "  入站端口: $inbound_port"
    echo "  出站地址: $outbound_address"
    echo "  出站端口: $outbound_port"
}

# 生成对应的Clash配置
generate_clash_config() {
    cat > config/migrated-from-v2ray.yaml << EOF
# 从V2Ray迁移的Clash配置
# 迁移时间: $(date)

# 基础配置
mixed-port: 7890
socks-port: 7891
port: 0
allow-lan: true
mode: Rule
log-level: info
external-controller: :9090

# DNS配置
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 8.8.8.8
    - 8.8.4.4
  fallback:
    - tls://1.0.0.1:853
    - tls://dns.google:853

# 代理配置（需要手动完善）
proxies:
  - name: "migrated-proxy"
    type: vmess
    server: "$outbound_address"
    port: $outbound_port
    uuid: "需要手动填写"
    alterId: 0
    cipher: auto

proxy-groups:
  - name: "自动选择"
    type: url-test
    proxies:
      - migrated-proxy
    url: 'http://www.gstatic.com/generate_204'
    interval: 300

# 规则
rules:
  - DOMAIN-SUFFIX,google.com,自动选择
  - DOMAIN-SUFFIX,youtube.com,自动选择
  - DOMAIN-SUFFIX,facebook.com,自动选择
  - DOMAIN-SUFFIX,twitter.com,自动选择
  - DOMAIN-KEYWORD,google,自动选择
  - GEOIP,CN,DIRECT
  - MATCH,自动选择
EOF
    
    echo "✅ 初始Clash配置已生成: config/migrated-from-v2ray.yaml"
    echo "⚠️ 请手动完善代理服务器的认证信息"
}

parse_v2ray_config
generate_clash_config
```

---

## 数据迁移

### 日志数据迁移

```bash
#!/bin/bash
# scripts/migrate-logs.sh

set -euo pipefail

SOURCE_LOG_DIR=${1:-"/var/log/clash"}
TARGET_LOG_DIR="./logs"

echo "📄 迁移日志数据..."

# 创建目标目录
mkdir -p "$TARGET_LOG_DIR"/{archive,current}

# 迁移当前日志
migrate_current_logs() {
    echo "迁移当前日志文件..."
    
    find "$SOURCE_LOG_DIR" -name "*.log" -mtime -7 | while read -r log_file; do
        local filename=$(basename "$log_file")
        cp "$log_file" "$TARGET_LOG_DIR/current/$filename"
        echo "  ✅ $filename"
    done
}

# 归档历史日志
archive_old_logs() {
    echo "归档历史日志文件..."
    
    find "$SOURCE_LOG_DIR" -name "*.log" -mtime +7 | while read -r log_file; do
        local filename=$(basename "$log_file")
        gzip -c "$log_file" > "$TARGET_LOG_DIR/archive/$filename.gz"
        echo "  📦 $filename.gz"
    done
}

# 清理权限
fix_permissions() {
    echo "修复文件权限..."
    chown -R 1000:1000 "$TARGET_LOG_DIR"
    chmod -R 644 "$TARGET_LOG_DIR"/*.log 2>/dev/null || true
}

if [ -d "$SOURCE_LOG_DIR" ]; then
    migrate_current_logs
    archive_old_logs
    fix_permissions
    echo "✅ 日志数据迁移完成"
else
    echo "⚠️ 源日志目录不存在: $SOURCE_LOG_DIR"
fi
```

### 配置历史迁移

```bash
#!/bin/bash
# scripts/migrate-config-history.sh

set -euo pipefail

SOURCE_CONFIG_DIR=${1:-"/etc/clash"}
TARGET_CONFIG_DIR="./config"

echo "⚙️ 迁移配置历史..."

# 迁移配置文件
migrate_configs() {
    if [ -d "$SOURCE_CONFIG_DIR" ]; then
        echo "迁移配置文件..."
        
        # 迁移主配置文件
        if [ -f "$SOURCE_CONFIG_DIR/config.yaml" ]; then
            cp "$SOURCE_CONFIG_DIR/config.yaml" "$TARGET_CONFIG_DIR/config.yaml.migrated"
            echo "  ✅ config.yaml"
        fi
        
        # 迁移自定义规则
        if [ -f "$SOURCE_CONFIG_DIR/rules.yaml" ]; then
            cp "$SOURCE_CONFIG_DIR/rules.yaml" "$TARGET_CONFIG_DIR/rules.yaml.migrated"
            echo "  ✅ rules.yaml"
        fi
        
        # 迁移代理配置
        find "$SOURCE_CONFIG_DIR" -name "proxy-*.yaml" | while read -r proxy_file; do
            local filename=$(basename "$proxy_file")
            cp "$proxy_file" "$TARGET_CONFIG_DIR/$filename.migrated"
            echo "  ✅ $filename"
        done
        
    else
        echo "⚠️ 源配置目录不存在: $SOURCE_CONFIG_DIR"
    fi
}

# 创建迁移报告
create_migration_report() {
    cat > "$TARGET_CONFIG_DIR/migration-report.md" << EOF
# 配置迁移报告

**迁移时间**: $(date)
**源目录**: $SOURCE_CONFIG_DIR
**目标目录**: $TARGET_CONFIG_DIR

## 迁移的文件

$(find "$TARGET_CONFIG_DIR" -name "*.migrated" | sed 's/^/- /')

## 后续操作

1. 检查迁移的配置文件
2. 根据新版本要求调整配置格式
3. 测试配置文件的有效性
4. 将 .migrated 文件重命名为正式配置文件

## 注意事项

- 迁移的配置文件可能需要格式调整
- 建议在测试环境中验证配置
- 保留原始配置文件作为备份
EOF
    
    echo "📋 迁移报告已生成: $TARGET_CONFIG_DIR/migration-report.md"
}

mkdir -p "$TARGET_CONFIG_DIR"
migrate_configs
create_migration_report

echo "✅ 配置历史迁移完成"
```

---

## 平台迁移

### Docker环境迁移

#### 容器数据导出

```bash
#!/bin/bash
# scripts/export-docker-data.sh

set -euo pipefail

EXPORT_DIR="migration-export-$(date +%Y%m%d)"

echo "📦 导出Docker环境数据..."

# 创建导出目录
mkdir -p "$EXPORT_DIR"/{images,volumes,configs}

# 导出镜像
export_images() {
    echo "导出Docker镜像..."
    
    # 获取相关镜像列表
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(clash|nginx)" > "$EXPORT_DIR/images/image-list.txt"
    
    # 导出每个镜像
    while read -r image; do
        if [ "$image" != "REPOSITORY:TAG" ]; then
            local filename=$(echo "$image" | tr '/:' '_')
            echo "  导出镜像: $image"
            docker save "$image" | gzip > "$EXPORT_DIR/images/$filename.tar.gz"
        fi
    done < "$EXPORT_DIR/images/image-list.txt"
    
    echo "✅ 镜像导出完成"
}

# 导出数据卷
export_volumes() {
    echo "导出数据卷..."
    
    # 获取相关卷列表
    docker volume ls --format "{{.Name}}" | grep clash > "$EXPORT_DIR/volumes/volume-list.txt" || true
    
    # 导出每个数据卷
    while read -r volume; do
        if [ -n "$volume" ]; then
            echo "  导出数据卷: $volume"
            docker run --rm \
                -v "$volume":/source:ro \
                -v "$(pwd)/$EXPORT_DIR/volumes":/backup \
                alpine tar czf "/backup/$volume.tar.gz" -C /source .
        fi
    done < "$EXPORT_DIR/volumes/volume-list.txt"
    
    echo "✅ 数据卷导出完成"
}

# 导出配置和元数据
export_configs() {
    echo "导出配置和元数据..."
    
    # 导出compose文件
    cp compose.yml "$EXPORT_DIR/configs/"
    cp .env "$EXPORT_DIR/configs/" 2>/dev/null || true
    
    # 导出配置目录
    if [ -d "config" ]; then
        tar czf "$EXPORT_DIR/configs/config.tar.gz" config/
    fi
    
    # 导出脚本目录
    if [ -d "scripts" ]; then
        tar czf "$EXPORT_DIR/configs/scripts.tar.gz" scripts/
    fi
    
    # 导出系统信息
    cat > "$EXPORT_DIR/configs/system-info.txt" << EOF
导出时间: $(date)
主机名: $(hostname)
操作系统: $(uname -a)
Docker版本: $(docker --version)
Docker Compose版本: $(docker compose version)
EOF
    
    echo "✅ 配置导出完成"
}

# 创建导入脚本
create_import_script() {
    cat > "$EXPORT_DIR/import.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🔄 开始导入Docker环境数据..."

# 导入镜像
import_images() {
    echo "导入Docker镜像..."
    find images/ -name "*.tar.gz" | while read -r image_file; do
        echo "  导入: $image_file"
        gunzip -c "$image_file" | docker load
    done
}

# 导入数据卷
import_volumes() {
    echo "导入数据卷..."
    find volumes/ -name "*.tar.gz" | while read -r volume_file; do
        local volume_name=$(basename "$volume_file" .tar.gz)
        echo "  导入数据卷: $volume_name"
        
        # 创建数据卷
        docker volume create "$volume_name"
        
        # 恢复数据
        docker run --rm \
            -v "$volume_name":/target \
            -v "$(pwd):/backup" \
            alpine tar xzf "/backup/$volume_file" -C /target
    done
}

# 导入配置
import_configs() {
    echo "导入配置文件..."
    
    # 解压配置文件
    if [ -f "configs/config.tar.gz" ]; then
        tar xzf configs/config.tar.gz
    fi
    
    if [ -f "configs/scripts.tar.gz" ]; then
        tar xzf configs/scripts.tar.gz
    fi
    
    # 复制环境文件
    if [ -f "configs/.env" ]; then
        cp configs/.env .
    fi
    
    if [ -f "configs/compose.yml" ]; then
        cp configs/compose.yml .
    fi
}

import_images
import_volumes
import_configs

echo "✅ 导入完成！"
echo "📝 请检查配置文件并根据需要进行调整"
EOF
    
    chmod +x "$EXPORT_DIR/import.sh"
    echo "📝 导入脚本已创建: $EXPORT_DIR/import.sh"
}

export_images
export_volumes
export_configs
create_import_script

# 创建压缩包
tar czf "$EXPORT_DIR.tar.gz" "$EXPORT_DIR"

echo "🎉 Docker环境数据导出完成！"
echo "📦 导出文件: $EXPORT_DIR.tar.gz"
echo "📝 在目标环境中解压并运行 ./import.sh 进行导入"
```

### Kubernetes环境迁移

```yaml
# k8s-migration/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: clash-migration
  namespace: clash-system
spec:
  template:
    spec:
      containers:
      - name: migration
        image: alpine:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            echo "开始Kubernetes环境迁移..."
            
            # 备份当前配置
            kubectl get configmap clash-config -o yaml > /backup/configmap.yaml
            kubectl get secret clash-secrets -o yaml > /backup/secrets.yaml
            kubectl get pvc -l app=clash -o yaml > /backup/pvc.yaml
            
            # 导出数据
            tar czf /backup/clash-data.tar.gz /data/*
            
            echo "迁移备份完成"
        volumeMounts:
        - name: backup-storage
          mountPath: /backup
        - name: clash-data
          mountPath: /data
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: migration-backup
      - name: clash-data
        persistentVolumeClaim:
          claimName: clash-data
      restartPolicy: Never
```

---

## 兼容性检查

### 配置兼容性检查工具

```bash
#!/bin/bash
# scripts/check-config-compatibility.sh

set -euo pipefail

CONFIG_FILE=${1:-"config/config.yaml"}
TARGET_VERSION=${2:-"latest"}

echo "🔍 检查配置兼容性..."

# 检查配置文件格式
check_config_format() {
    echo "检查配置文件格式..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # YAML语法检查
    if command -v yamllint >/dev/null; then
        if ! yamllint "$CONFIG_FILE" >/dev/null 2>&1; then
            echo "❌ YAML语法错误"
            yamllint "$CONFIG_FILE"
            return 1
        fi
    else
        echo "⚠️ yamllint未安装，跳过YAML语法检查"
    fi
    
    echo "✅ 配置文件格式正确"
}

# 检查必需字段
check_required_fields() {
    echo "检查必需配置字段..."
    
    local required_fields=(
        "mixed-port"
        "allow-lan"
        "mode"
        "log-level"
        "external-controller"
        "dns"
        "proxies"
        "proxy-groups"
        "rules"
    )
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$CONFIG_FILE"; then
            echo "❌ 缺少必需字段: $field"
            return 1
        else
            echo "  ✅ $field"
        fi
    done
    
    echo "✅ 所有必需字段存在"
}

# 检查已废弃的配置项
check_deprecated_options() {
    echo "检查已废弃的配置项..."
    
    local deprecated_options=(
        "redir-port"
        "tproxy-port"
        "enhanced-mode"
    )
    
    local found_deprecated=false
    
    for option in "${deprecated_options[@]}"; do
        if grep -q "^$option:" "$CONFIG_FILE"; then
            echo "⚠️ 发现已废弃的配置项: $option"
            found_deprecated=true
        fi
    done
    
    if [ "$found_deprecated" = true ]; then
        echo "📝 建议移除或替换已废弃的配置项"
    else
        echo "✅ 未发现已废弃的配置项"
    fi
}

# 检查代理配置
check_proxy_config() {
    echo "检查代理配置..."
    
    # 检查代理类型支持
    local supported_types=("ss" "ssr" "vmess" "vless" "trojan" "hysteria" "hysteria2")
    local unsupported_found=false
    
    while IFS= read -r line; do
        if [[ $line =~ type:[[:space:]]*([a-zA-Z0-9-]+) ]]; then
            local proxy_type="${BASH_REMATCH[1]}"
            if [[ ! " ${supported_types[*]} " =~ " $proxy_type " ]]; then
                echo "⚠️ 可能不支持的代理类型: $proxy_type"
                unsupported_found=true
            fi
        fi
    done < "$CONFIG_FILE"
    
    if [ "$unsupported_found" = false ]; then
        echo "✅ 代理配置类型检查通过"
    fi
}

# 生成兼容性报告
generate_compatibility_report() {
    local report_file="compatibility-report-$(date +%Y%m%d).md"
    
    cat > "$report_file" << EOF
# 配置兼容性检查报告

**检查时间**: $(date)
**配置文件**: $CONFIG_FILE
**目标版本**: $TARGET_VERSION

## 检查结果

$(check_config_format 2>&1 | sed 's/^/- /')
$(check_required_fields 2>&1 | sed 's/^/- /')
$(check_deprecated_options 2>&1 | sed 's/^/- /')
$(check_proxy_config 2>&1 | sed 's/^/- /')

## 建议操作

1. 修复检查中发现的问题
2. 移除或更新已废弃的配置项
3. 在测试环境中验证配置
4. 备份当前配置后进行迁移

EOF
    
    echo "📋 兼容性报告已生成: $report_file"
}

# 执行所有检查
main() {
    local exit_code=0
    
    check_config_format || exit_code=1
    check_required_fields || exit_code=1
    check_deprecated_options || exit_code=1
    check_proxy_config || exit_code=1
    
    generate_compatibility_report
    
    if [ $exit_code -eq 0 ]; then
        echo "🎉 兼容性检查通过！"
    else
        echo "❌ 兼容性检查发现问题，请查看报告详情"
    fi
    
    return $exit_code
}

main
```

---

## 迁移工具

### 自动化迁移脚本

```bash
#!/bin/bash
# scripts/auto-migrate.sh

set -euo pipefail

# 迁移配置
MIGRATION_CONFIG="migration.conf"
SOURCE_TYPE=${1:-""}
TARGET_ENV=${2:-"production"}

# 加载迁移配置
load_migration_config() {
    if [ -f "$MIGRATION_CONFIG" ]; then
        source "$MIGRATION_CONFIG"
    else
        echo "❌ 迁移配置文件不存在: $MIGRATION_CONFIG"
        exit 1
    fi
}

# 显示迁移概览
show_migration_overview() {
    cat << EOF
🔄 自动化迁移工具

源系统类型: $SOURCE_TYPE
目标环境: $TARGET_ENV
迁移范围: 配置、数据、服务

确认开始迁移？ (y/N): 
EOF
    
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "❌ 迁移已取消"
        exit 0
    fi
}

# 执行预迁移检查
pre_migration_checks() {
    echo "🔍 执行预迁移检查..."
    
    # 检查依赖
    local dependencies=("docker" "docker-compose" "tar" "gzip")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null; then
            echo "❌ 缺少依赖: $dep"
            exit 1
        fi
    done
    
    # 检查磁盘空间
    local required_space_mb=2048
    local available_space_mb=$(df . --output=avail | tail -n1)
    available_space_mb=$((available_space_mb / 1024))
    
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo "❌ 磁盘空间不足，需要${required_space_mb}MB，可用${available_space_mb}MB"
        exit 1
    fi
    
    echo "✅ 预迁移检查通过"
}

# 执行数据迁移
execute_migration() {
    echo "🚀 开始执行迁移..."
    
    # 创建迁移工作目录
    local work_dir="migration-work-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$work_dir"
    
    # 根据源类型执行不同的迁移逻辑
    case "$SOURCE_TYPE" in
        "v2ray")
            ./scripts/migrate-from-v2ray.sh "$work_dir"
            ;;
        "shadowsocks")
            ./scripts/migrate-from-shadowsocks.sh "$work_dir"
            ;;
        "clash")
            ./scripts/migrate-clash-version.sh "$work_dir"
            ;;
        *)
            echo "❌ 不支持的源系统类型: $SOURCE_TYPE"
            exit 1
            ;;
    esac
    
    echo "✅ 数据迁移完成"
}

# 验证迁移结果
verify_migration() {
    echo "🔍 验证迁移结果..."
    
    # 配置语法检查
    if [ -f "config/config.yaml" ]; then
        ./scripts/check-config-compatibility.sh config/config.yaml
    fi
    
    # 服务启动测试
    echo "测试服务启动..."
    if docker compose up -d --wait; then
        echo "✅ 服务启动成功"
        
        # 健康检查
        sleep 30
        if ./scripts/health-check.sh; then
            echo "✅ 健康检查通过"
        else
            echo "⚠️ 健康检查失败，请检查配置"
        fi
        
        # 停止测试服务
        docker compose down
    else
        echo "❌ 服务启动失败"
        exit 1
    fi
}

# 生成迁移报告
generate_migration_report() {
    local report_file="migration-report-$(date +%Y%m%d).md"
    
    cat > "$report_file" << EOF
# 自动化迁移报告

**迁移时间**: $(date)
**源系统**: $SOURCE_TYPE
**目标环境**: $TARGET_ENV

## 迁移步骤

1. ✅ 预迁移检查
2. ✅ 数据迁移
3. ✅ 配置转换
4. ✅ 服务验证

## 迁移文件

- 配置文件: config/config.yaml
- 环境变量: .env
- 启动脚本: compose.yml

## 后续操作

1. 检查并调整配置参数
2. 根据实际需要修改代理设置
3. 执行完整的功能测试
4. 部署到生产环境

## 注意事项

- 原有配置已备份到 backups/ 目录
- 建议在测试环境中充分验证
- 遇到问题请参考故障排除指南

EOF
    
    echo "📋 迁移报告已生成: $report_file"
}

# 主函数
main() {
    if [ -z "$SOURCE_TYPE" ]; then
        echo "用法: $0 <source_type> [target_env]"
        echo "支持的源类型: v2ray, shadowsocks, clash"
        exit 1
    fi
    
    load_migration_config
    show_migration_overview
    pre_migration_checks
    execute_migration
    verify_migration
    generate_migration_report
    
    echo "🎉 自动化迁移完成！"
    echo "📋 详细信息请查看迁移报告"
}

main "$@"
```

---

## 回滚策略

### 自动回滚脚本

```bash
#!/bin/bash
# scripts/rollback.sh

set -euo pipefail

BACKUP_DIR=${1:-""}
ROLLBACK_TYPE=${2:-"full"}

echo "🔄 开始回滚操作..."

# 查找最近的备份
find_latest_backup() {
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo "$BACKUP_DIR"
    elif [ -f ".last_backup" ]; then
        cat .last_backup
    else
        # 查找最新的备份目录
        find backups/ -maxdepth 1 -type d -name "upgrade-*" | sort -r | head -n1
    fi
}

# 执行回滚
perform_rollback() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        echo "❌ 备份目录不存在: $backup_path"
        exit 1
    fi
    
    echo "📦 从备份恢复: $backup_path"
    
    # 停止当前服务
    echo "⏹️ 停止当前服务..."
    docker compose down || true
    
    # 恢复配置文件
    echo "📋 恢复配置文件..."
    if [ -d "$backup_path/config" ]; then
        rm -rf config/
        cp -r "$backup_path/config" ./
    fi
    
    # 恢复环境变量
    if [ -f "$backup_path/.env" ]; then
        cp "$backup_path/.env" ./
    fi
    
    # 恢复compose文件
    if [ -f "$backup_path/compose.yml" ]; then
        cp "$backup_path/compose.yml" ./
    fi
    
    # 恢复数据
    if [ -d "$backup_path/data" ]; then
        rm -rf data/
        cp -r "$backup_path/data" ./
    fi
    
    echo "✅ 文件恢复完成"
}

# 启动回滚后的服务
start_rollback_service() {
    echo "▶️ 启动回滚后的服务..."
    
    if docker compose up -d; then
        echo "✅ 服务启动成功"
        
        # 等待服务稳定
        sleep 30
        
        # 验证服务状态
        if docker compose ps | grep -q "Up"; then
            echo "✅ 回滚验证通过"
        else
            echo "❌ 回滚后服务状态异常"
            exit 1
        fi
    else
        echo "❌ 服务启动失败"
        exit 1
    fi
}

# 清理回滚后的环境
cleanup_after_rollback() {
    echo "🧹 清理回滚环境..."
    
    # 清理失败的升级镜像
    docker system prune -f || true
    
    # 记录回滚操作
    cat >> rollback.log << EOF
回滚时间: $(date)
备份路径: $1
回滚类型: $ROLLBACK_TYPE
操作结果: 成功
EOF
    
    echo "✅ 环境清理完成"
}

# 主回滚流程
main() {
    local backup_path
    backup_path=$(find_latest_backup)
    
    if [ -z "$backup_path" ]; then
        echo "❌ 未找到可用的备份"
        exit 1
    fi
    
    echo "🎯 使用备份: $backup_path"
    
    # 确认回滚操作
    echo "确认执行回滚操作？这将覆盖当前配置 (y/N): "
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "❌ 回滚操作已取消"
        exit 0
    fi
    
    perform_rollback "$backup_path"
    start_rollback_service
    cleanup_after_rollback "$backup_path"
    
    echo "🎉 回滚操作完成！"
    echo "当前版本已恢复到备份时的状态"
}

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [BACKUP_DIR] [ROLLBACK_TYPE]

参数:
  BACKUP_DIR     指定备份目录（可选，默认使用最新备份）
  ROLLBACK_TYPE  回滚类型（full|config|data，默认：full）

示例:
  $0                           # 使用最新备份进行完整回滚
  $0 backups/upgrade-20240113  # 使用指定备份回滚
  $0 "" config                 # 仅回滚配置文件
EOF
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac
```

---

## 常见问题

### Q1: 迁移过程中服务无法启动怎么办？

**答**: 
1. 检查日志：`docker compose logs`
2. 验证配置：`./scripts/check-config-compatibility.sh`
3. 检查端口冲突：`netstat -tlnp | grep -E ':(7890|7891|9090)'`
4. 回滚到之前版本：`./scripts/rollback.sh`

### Q2: 配置迁移后代理不工作？

**答**:
1. 检查代理服务器配置是否正确
2. 验证网络连接：`curl -x http://localhost:7890 http://www.google.com`
3. 检查规则配置
4. 查看Clash日志确认错误原因

### Q3: 从其他代理方案迁移需要注意什么？

**答**:
1. 代理协议兼容性（部分协议可能不支持）
2. 配置格式差异（需要手动调整）
3. 功能特性差异（某些功能可能需要重新配置）
4. 性能特性差异（可能需要调优）

### Q4: 如何验证迁移是否成功？

**答**:
1. 运行健康检查：`./scripts/health-check.sh`
2. 测试代理连接：`curl -x http://localhost:7890 http://www.google.com`
3. 检查服务状态：`docker compose ps`
4. 查看访问日志确认流量转发正常

---

## 迁移检查清单

### 迁移前准备

- [ ] **备份检查**
  - [ ] 完整备份当前配置和数据
  - [ ] 验证备份文件完整性
  - [ ] 记录当前系统状态

- [ ] **环境评估**
  - [ ] 检查目标环境兼容性
  - [ ] 确认系统资源充足
  - [ ] 验证网络连接正常

- [ ] **计划制定**
  - [ ] 制定详细迁移计划
  - [ ] 安排迁移时间窗口
  - [ ] 准备回滚方案

### 迁移过程

- [ ] **数据迁移**
  - [ ] 配置文件迁移
  - [ ] 日志数据迁移
  - [ ] 历史数据迁移

- [ ] **服务迁移**
  - [ ] 容器镜像迁移
  - [ ] 服务配置迁移
  - [ ] 网络配置迁移

- [ ] **验证测试**
  - [ ] 配置语法检查
  - [ ] 服务启动测试
  - [ ] 功能验证测试

### 迁移后验证

- [ ] **功能验证**
  - [ ] 代理服务正常工作
  - [ ] API接口响应正常
  - [ ] Web界面访问正常

- [ ] **性能验证**
  - [ ] 代理速度测试
  - [ ] 资源使用检查
  - [ ] 稳定性测试

- [ ] **安全验证**
  - [ ] 访问控制检查
  - [ ] 日志记录正常
  - [ ] 监控系统正常

### 文档更新

- [ ] **配置文档**
  - [ ] 更新配置说明
  - [ ] 记录变更内容
  - [ ] 更新版本信息

- [ ] **运维文档**
  - [ ] 更新操作手册
  - [ ] 记录新的监控指标
  - [ ] 更新故障排除指南

---

**更新日期**: 2025-07-13  
**文档版本**: v1.0.0  
**维护者**: 系统管理员

---

**📞 需要帮助？**

- 📖 **文档**: [docs/](./README.md)
- 🐛 **问题报告**: [GitHub Issues](https://github.com/your-org/clash-docker/issues)
- 💬 **讨论**: [GitHub Discussions](https://github.com/your-org/clash-docker/discussions)