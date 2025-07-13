# 🔧 故障排除指南

## 📚 目录

1. [常见问题](#常见问题)
2. [错误诊断流程](#错误诊断流程)
3. [日志分析](#日志分析)
4. [网络连接问题](#网络连接问题)
5. [配置文件问题](#配置文件问题)
6. [性能问题](#性能问题)
7. [安全问题](#安全问题)
8. [Docker相关问题](#docker相关问题)
9. [高级诊断工具](#高级诊断工具)

---

## 常见问题

### Q1: 容器启动失败

**症状**: Docker Compose启动时容器立即退出

**可能原因**:
- 端口被占用
- 环境变量配置错误
- 配置文件语法错误
- 权限问题

**解决步骤**:
```bash
# 1. 检查端口占用
netstat -tlnp | grep -E ':(7890|7891|8088|9090)'

# 2. 检查环境变量
./scripts/validate-env.sh

# 3. 查看容器日志
docker compose logs clash
docker compose logs nginx

# 4. 检查配置文件
python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"

# 5. 重新生成配置
./scripts/generate-config-advanced.sh
```

### Q2: 代理连接失败

**症状**: 浏览器配置代理后无法访问网站

**解决步骤**:
```bash
# 1. 检查Clash服务状态
curl http://localhost:9090/version

# 2. 测试代理端口
curl -I --proxy socks5://localhost:7891 http://www.google.com
curl -I --proxy http://localhost:7890 http://www.google.com

# 3. 检查代理节点状态
curl http://localhost:9090/proxies

# 4. 查看Clash日志
docker compose logs -f clash
```

### Q3: 配置生成失败

**症状**: 运行生成脚本时出现错误

**常见错误代码**:
- `CONFIG_GENERATION_ERROR`: 配置生成失败
- `TEMPLATE_NOT_FOUND`: 模板文件不存在
- `ENV_VAR_MISSING`: 环境变量缺失
- `YAML_SYNTAX_ERROR`: YAML语法错误

**解决步骤**:
```bash
# 1. 启用详细调试模式
DEBUG=true ./scripts/generate-config-advanced.sh

# 2. 检查模板文件
ls -la config/clash-template.yaml config/rules-template.yaml

# 3. 验证环境变量
env | grep -E '^(CLASH_|PROXY_|NGINX_)' | sort

# 4. 手动测试模板替换
envsubst < config/clash-template.yaml > /tmp/test-config.yaml
```

### Q4: Web界面无法访问

**症状**: 浏览器访问http://localhost:8088时连接失败

**解决步骤**:
```bash
# 1. 检查Nginx状态
docker compose ps nginx

# 2. 检查端口绑定
docker compose port nginx 80

# 3. 测试本地连接
curl -I http://localhost:8088

# 4. 检查认证配置
curl -u admin:password http://localhost:8088
```

## 错误诊断流程

### 诊断决策树

```
问题出现
    │
    ├─ 容器相关？
    │   ├─ 是 → 检查Docker状态
    │   └─ 否 → 继续
    │
    ├─ 网络相关？
    │   ├─ 是 → 检查端口和防火墙
    │   └─ 否 → 继续
    │
    ├─ 配置相关？
    │   ├─ 是 → 验证配置文件
    │   └─ 否 → 继续
    │
    └─ 性能相关？
        ├─ 是 → 检查资源使用
        └─ 否 → 查看系统日志
```

### 系统性诊断命令

```bash
#!/bin/bash
# 一键诊断脚本

echo "=== 系统状态检查 ==="
docker compose ps

echo "=== 端口检查 ==="
netstat -tlnp | grep -E ':(7890|7891|8088|9090)'

echo "=== 配置验证 ==="
./scripts/validate-env.sh

echo "=== 健康检查 ==="
./scripts/health-check.sh

echo "=== 日志摘要 ==="
docker compose logs --tail=20
```

## 日志分析

### 日志文件位置

- **Clash日志**: `docker compose logs clash`
- **Nginx日志**: `docker compose logs nginx`
- **配置生成日志**: `logs/config-generation.log`
- **健康检查日志**: `logs/health-check.log`

### 关键日志模式

#### Clash服务日志
```bash
# 正常启动
grep "HTTP proxy listening at" logs/clash.log

# 配置错误
grep -i "error\|fatal" logs/clash.log

# 连接问题
grep "dial\|connect\|timeout" logs/clash.log
```

#### Nginx访问日志
```bash
# 查看访问模式
awk '{print $1, $7, $9}' logs/nginx-access.log | sort | uniq -c

# 查找错误请求
grep " [45][0-9][0-9] " logs/nginx-access.log

# 分析访问频率
awk '{print $4}' logs/nginx-access.log | cut -d: -f2 | sort | uniq -c
```

### 日志级别调优

```bash
# 临时启用调试日志
docker compose exec clash clash -d /app/config -l debug

# 永久调整日志级别
echo "CLASH_LOG_LEVEL=debug" >> .env
docker compose restart clash
```

## 网络连接问题

### 网络连通性测试

```bash
# 测试外部连接
ping -c 3 8.8.8.8

# 测试DNS解析
nslookup google.com

# 测试代理服务器连接
telnet your.proxy.server 443

# 测试本地端口
telnet localhost 7890
telnet localhost 7891
```

### 防火墙配置

#### Ubuntu/Debian
```bash
# 检查防火墙状态
sudo ufw status

# 允许必要端口
sudo ufw allow 7890/tcp
sudo ufw allow 7891/tcp
sudo ufw allow 8088/tcp
```

#### CentOS/RHEL
```bash
# 检查防火墙状态
sudo firewall-cmd --state

# 允许端口
sudo firewall-cmd --permanent --add-port=7890/tcp
sudo firewall-cmd --permanent --add-port=7891/tcp
sudo firewall-cmd --reload
```

### 代理链测试

```bash
# 测试代理链连接
curl --proxy socks5://localhost:7891 \
     --proxy-header "User-Agent: Test" \
     -I http://httpbin.org/ip

# 测试特定代理节点
curl http://localhost:9090/proxies/节点1/delay?timeout=5000&url=http://www.gstatic.com/generate_204
```

## 配置文件问题

### YAML语法验证

```bash
# Python验证
python3 -c "
import yaml
try:
    with open('config/config.yaml') as f:
        yaml.safe_load(f)
    print('YAML语法正确')
except yaml.YAMLError as e:
    print(f'YAML语法错误: {e}')
"

# 使用yamllint
yamllint config/config.yaml
```

### 配置逻辑验证

```bash
# 检查代理配置
grep -A 10 "^proxies:" config/config.yaml

# 检查规则配置
grep -A 10 "^rules:" config/config.yaml

# 验证代理组配置
grep -A 20 "^proxy-groups:" config/config.yaml
```

### 环境变量问题

```bash
# 查找未替换的变量
grep '\${[^}]*}' config/config.yaml

# 检查变量定义
env | grep -E '^(CLASH_|PROXY_|NGINX_)' > /tmp/env_vars.txt
grep -o '\${[^}]*}' config/clash-template.yaml | sed 's/[${} ]//g' | sort -u > /tmp/template_vars.txt

# 找出缺失的变量
comm -23 /tmp/template_vars.txt /tmp/env_vars.txt
```

## 性能问题

### 系统资源监控

```bash
# CPU和内存使用
docker stats

# 磁盘使用
df -h
du -sh config/ logs/

# 网络连接数
netstat -an | grep -E ':(7890|7891)' | wc -l

# 进程状态
ps aux | grep -E '(clash|nginx)'
```

### 性能调优

#### 调整Clash配置
```yaml
# 增加连接池大小
experimental:
  sniff-tls-sni: true
  interface-name: eth0

# 优化DNS配置
dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
```

#### Docker资源限制
```yaml
# compose.yml
services:
  clash:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
```

### 网络性能测试

```bash
# 带宽测试
iperf3 -c your.proxy.server

# 延迟测试
ping -c 10 your.proxy.server

# 代理性能测试
time curl --proxy socks5://localhost:7891 -I http://www.google.com
```

## 安全问题

### 权限检查

```bash
# 检查文件权限
ls -la config/
ls -la security/

# 检查容器权限
docker compose exec clash whoami
docker compose exec nginx whoami

# 检查端口绑定
netstat -tlnp | grep -E ':(7890|7891|8088|9090)'
```

### 安全配置验证

```bash
# 检查认证配置
curl -I http://localhost:8088

# 验证SSL/TLS配置
openssl s_client -connect your.proxy.server:443 -servername your.domain

# 检查敏感信息泄露
grep -r "password\|secret\|key" config/ --exclude="*.example"
```

## Docker相关问题

### 容器状态诊断

```bash
# 检查容器状态
docker compose ps -a

# 查看容器详细信息
docker compose exec clash cat /etc/passwd
docker compose exec clash ps aux

# 检查网络配置
docker network ls
docker compose exec clash ip addr show
```

### 镜像问题

```bash
# 检查镜像
docker images | grep clash

# 清理镜像缓存
docker system prune -a

# 重新构建
docker compose build --no-cache
```

### 存储问题

```bash
# 检查磁盘空间
docker system df

# 清理未使用资源
docker system prune -f

# 检查挂载点
docker compose exec clash df -h
```

## 高级诊断工具

### 网络抓包分析

```bash
# 安装tcpdump
sudo apt-get install tcpdump

# 抓取代理流量
sudo tcpdump -i any -n 'port 7890 or port 7891'

# 分析HTTP请求
sudo tcpdump -i any -A 'port 8088'
```

### 系统调用跟踪

```bash
# 跟踪Clash进程
sudo strace -p $(pgrep clash) -e trace=network

# 跟踪文件操作
sudo strace -p $(pgrep clash) -e trace=file
```

### 性能分析

```bash
# CPU性能分析
perf top -p $(pgrep clash)

# 内存分析
valgrind --tool=memcheck --leak-check=full clash
```

---

## 📞 获取更多帮助

如果以上方法无法解决问题，请：

1. **查看官方文档**: [docs/README.md](README.md)
2. **提交Issue**: [GitHub Issues](https://github.com/your-org/clash-docker/issues)
3. **启用调试模式**: `DEBUG=true` 运行相关命令
4. **收集诊断信息**: 运行完整的诊断脚本并提供输出

**更新日期**: 2025-07-13  
**版本**: v1.0.0  
**维护者**: Clash Docker Team