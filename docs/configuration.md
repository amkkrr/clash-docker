# 配置指南

## 环境变量详解

### 基础配置

#### 服务端口配置
```bash
# Clash 核心端口
CLASH_HTTP_PORT=7890          # HTTP代理端口
CLASH_SOCKS_PORT=7891         # SOCKS5代理端口
CLASH_CONTROL_PORT=9090       # 控制API端口
CLASH_MIXED_PORT=7892         # 混合代理端口（可选）

# Nginx 服务端口
NGINX_PORT=8088               # Web服务端口
BIND_ADDRESS=127.0.0.1        # 绑定地址（安全考虑）
```

#### 代理服务器配置
```bash
# 第一个代理节点
PROXY_NAME_1="节点1"
PROXY_TYPE_1=ss               # 代理类型: ss, vmess, trojan, socks5
PROXY_SERVER_1=server1.example.com
PROXY_PORT_1=443
PROXY_PASSWORD_1=your_password
PROXY_CIPHER_1=aes-256-gcm    # 加密方式

# 第二个代理节点
PROXY_NAME_2="节点2"
PROXY_TYPE_2=vmess
PROXY_SERVER_2=server2.example.com
PROXY_PORT_2=443
PROXY_UUID_2=uuid-string
PROXY_ALTERID_2=0
PROXY_CIPHER_2=auto
```

#### Clash 运行配置
```bash
# 基本设置
CLASH_MODE=rule               # 运行模式: rule, global, direct
CLASH_LOG_LEVEL=info          # 日志级别: debug, info, warning, error, silent
CLASH_ALLOW_LAN=false         # 是否允许局域网连接
CLASH_SECRET=your_secret_key  # API认证密钥

# DNS 配置
DNS_ENABLED=true
DNS_LISTEN=127.0.0.1:5353
DNS_FALLBACK_1=8.8.8.8
DNS_FALLBACK_2=1.1.1.1
```

#### 规则配置
```bash
# 规则集
RULE_MODE=rule
CUSTOM_RULES_ENABLED=true

# 域名规则
DOMAIN_DIRECT="*.local,*.lan,localhost"
DOMAIN_PROXY="*.google.com,*.youtube.com,*.github.com"
DOMAIN_REJECT="*.ads.com,*.analytics.com"

# 地理位置规则
GEOIP_DIRECT=CN,LAN
GEOIP_PROXY=US,HK,TW,JP,SG
```

## 代理类型配置详解

### Shadowsocks 配置
```bash
PROXY_TYPE_1=ss
PROXY_SERVER_1=ss.example.com
PROXY_PORT_1=8388
PROXY_PASSWORD_1=password123
PROXY_CIPHER_1=aes-256-gcm
PROXY_UDP_1=true              # 可选：启用UDP转发
```

支持的加密方式：
- `aes-256-gcm`
- `aes-128-gcm` 
- `chacha20-ietf-poly1305`
- `xchacha20-ietf-poly1305`

### VMess 配置
```bash
PROXY_TYPE_2=vmess
PROXY_SERVER_2=vmess.example.com
PROXY_PORT_2=443
PROXY_UUID_2=550e8400-e29b-41d4-a716-446655440000
PROXY_ALTERID_2=0
PROXY_CIPHER_2=auto
PROXY_NETWORK_2=ws            # 可选：网络类型 tcp/ws/h2/grpc
PROXY_WS_PATH_2=/path         # 可选：WebSocket路径
PROXY_TLS_2=true              # 可选：启用TLS
```

### Trojan 配置
```bash
PROXY_TYPE_3=trojan
PROXY_SERVER_3=trojan.example.com
PROXY_PORT_3=443
PROXY_PASSWORD_3=trojan_password
PROXY_SNI_3=example.com       # 可选：SNI
PROXY_SKIP_CERT_VERIFY_3=false # 可选：跳过证书验证
```

### SOCKS5 配置
```bash
PROXY_TYPE_4=socks5
PROXY_SERVER_4=socks5.example.com
PROXY_PORT_4=1080
PROXY_USERNAME_4=user         # 可选：用户名
PROXY_PASSWORD_4=pass         # 可选：密码
PROXY_UDP_4=true              # 可选：UDP支持
```

### HTTP 代理配置
```bash
PROXY_TYPE_5=http
PROXY_SERVER_5=http.example.com
PROXY_PORT_5=8080
PROXY_USERNAME_5=user         # 可选：用户名
PROXY_PASSWORD_5=pass         # 可选：密码
PROXY_TLS_5=false             # 可选：启用HTTPS
```

## 高级配置

### 代理组配置
```bash
# 自动选择组
PROXY_GROUP_AUTO_ENABLED=true
PROXY_GROUP_AUTO_NAME="自动选择"
PROXY_GROUP_AUTO_TYPE=url-test
PROXY_GROUP_AUTO_URL="http://www.gstatic.com/generate_204"
PROXY_GROUP_AUTO_INTERVAL=300

# 手动选择组
PROXY_GROUP_SELECT_ENABLED=true
PROXY_GROUP_SELECT_NAME="手动选择"
PROXY_GROUP_SELECT_TYPE=select

# 负载均衡组
PROXY_GROUP_BALANCE_ENABLED=true
PROXY_GROUP_BALANCE_NAME="负载均衡"
PROXY_GROUP_BALANCE_TYPE=load-balance
PROXY_GROUP_BALANCE_STRATEGY=round-robin
```

### DNS 高级配置
```bash
# DNS 设置
DNS_ENABLED=true
DNS_LISTEN=127.0.0.1:5353
DNS_IPV6=false
DNS_USE_HOSTS=true
DNS_ENHANCED_MODE=fake-ip     # 模式: redir-host, fake-ip

# 上游DNS服务器
DNS_NAMESERVER_1=223.5.5.5
DNS_NAMESERVER_2=119.29.29.29
DNS_FALLBACK_1=8.8.8.8
DNS_FALLBACK_2=1.1.1.1

# DNS over HTTPS
DOH_ENABLED=true
DOH_URL_1="https://doh.pub/dns-query"
DOH_URL_2="https://dns.alidns.com/dns-query"

# 域名解析策略
DNS_FAKE_IP_RANGE=198.18.0.1/16
DNS_FAKE_IP_FILTER="*.lan,*.local,localhost"
```

### 规则配置
```bash
# 自定义规则
CUSTOM_RULES_1="DOMAIN-SUFFIX,google.com,PROXY"
CUSTOM_RULES_2="DOMAIN-KEYWORD,youtube,PROXY"
CUSTOM_RULES_3="IP-CIDR,192.168.0.0/16,DIRECT"
CUSTOM_RULES_4="GEOIP,CN,DIRECT"
CUSTOM_RULES_5="MATCH,PROXY"

# 规则提供商
RULE_PROVIDERS_ENABLED=true
RULE_PROVIDER_REJECT_URL="https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
RULE_PROVIDER_PROXY_URL="https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt"
RULE_PROVIDER_DIRECT_URL="https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt"
```

### 实验性功能
```bash
# 实验性功能
EXPERIMENTAL_ENABLED=true
SNIFF_TLS_SNI=true            # 嗅探TLS SNI
SNIFF_HTTP_HOST=true          # 嗅探HTTP Host
SKIP_AUTH_PREFIXES="127.0.0.0/8,::1/128" # 跳过认证的IP段

# 缓存配置
PROFILE_STORE_SELECTED=true   # 存储选择的代理
PROFILE_STORE_FAKE_IP=true    # 存储fake-ip映射
```

## 安全配置

### 访问控制
```bash
# API 安全
CLASH_SECRET=your_very_secure_secret_key
API_EXTERNAL_CONTROLLER=127.0.0.1:9090
API_EXTERNAL_UI_URL=""        # 留空禁用外部UI

# 网络绑定
BIND_ADDRESS=127.0.0.1        # 只绑定到本地
ALLOW_LAN=false               # 禁止局域网访问
AUTHENTICATION_REQUIRED=true  # 启用认证
```

### Nginx 认证配置
```bash
# HTTP 基本认证
NGINX_AUTH_ENABLED=true
NGINX_AUTH_USER=admin
NGINX_AUTH_PASS=secure_password_123

# IP 白名单
NGINX_WHITELIST_ENABLED=true
NGINX_WHITELIST_IPS="127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# 访问限制
NGINX_RATE_LIMIT=true
NGINX_RATE_LIMIT_RATE="5r/s"
NGINX_RATE_LIMIT_BURST=10
```

## 监控配置

### 日志配置
```bash
# 日志设置
LOG_LEVEL=info                # debug, info, warning, error, silent
LOG_TO_FILE=true
LOG_FILE_PATH=/app/logs/clash.log
LOG_MAX_SIZE=10M
LOG_MAX_BACKUPS=5

# 访问日志
NGINX_ACCESS_LOG=true
NGINX_ACCESS_LOG_FORMAT=combined
NGINX_ERROR_LOG_LEVEL=warn
```

### 健康检查配置
```bash
# 健康检查
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_INTERVAL=30      # 检查间隔（秒）
HEALTH_CHECK_TIMEOUT=10       # 超时时间（秒）
HEALTH_CHECK_URL="http://www.gstatic.com/generate_204"

# 指标收集
METRICS_ENABLED=true
METRICS_PORT=9091
METRICS_PATH=/metrics
```

## 环境变量验证

使用内置的验证脚本检查配置：

```bash
# 验证所有环境变量
./scripts/validate-env.sh

# 验证特定类型的配置
./scripts/validate-env.sh --proxy-only
./scripts/validate-env.sh --security-only
./scripts/validate-env.sh --network-only
```

## 配置模板

### 基础模板 (.env.basic)
```bash
# 最小配置，适用于简单场景
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090
NGINX_PORT=8088

PROXY_TYPE_1=ss
PROXY_SERVER_1=your.server.com
PROXY_PORT_1=443
PROXY_PASSWORD_1=your_password
PROXY_CIPHER_1=aes-256-gcm

CLASH_SECRET=your_secret_key
CLASH_MODE=rule
CLASH_LOG_LEVEL=info
```

### 企业模板 (.env.enterprise)
```bash
# 企业级配置，包含完整安全和监控
# [包含所有上述配置项]
# 适用于生产环境
```

### 开发模板 (.env.development)
```bash
# 开发环境配置
CLASH_LOG_LEVEL=debug
ALLOW_LAN=true
NGINX_AUTH_ENABLED=false
HEALTH_CHECK_INTERVAL=10
```

## 配置最佳实践

1. **安全原则**
   - 使用强密码和随机密钥
   - 启用认证和访问控制
   - 定期轮换密码
   - 监控访问日志

2. **性能优化**
   - 选择合适的加密算法
   - 配置适当的并发连接数
   - 启用DNS缓存
   - 使用负载均衡

3. **可靠性**
   - 配置多个代理节点
   - 启用自动故障切换
   - 设置健康检查
   - 定期备份配置

4. **监控和维护**
   - 启用详细日志
   - 配置指标收集
   - 设置告警规则
   - 定期检查配置

---

*更多配置选项请参考 [Clash 官方文档](https://dreamacro.github.io/clash/)*