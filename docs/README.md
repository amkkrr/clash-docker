# Clash Docker 企业级解决方案

## 📚 目录

1. [项目概述](#项目概述)
2. [核心特性](#核心特性)
3. [项目结构](#项目结构)
4. [快速开始](#快速开始)
5. [配置说明](#配置说明)
6. [部署模式](#部署模式)
7. [安全特性](#安全特性)
8. [监控和运维](#监控和运维)
9. [测试和质量保证](#测试和质量保证)
10. [故障排除](#故障排除)
11. [贡献指南](#贡献指南)
12. [许可证](#许可证)
13. [支持和联系](#支持和联系)

---

## 项目概述

这是一个企业级的 Clash 代理服务 Docker 解决方案，提供完整的配置管理、安全加固、监控和测试框架。项目采用环境变量管理敏感信息，支持多环境部署，并实现了全面的安全防护措施。

## 📚 文档导航

- 🔧 **[配置指南](./configuration.md)** - 详细配置说明
- 🏗️ **[前端开发](./FRONTEND_DEVELOPMENT_PLAN.md)** - 可视化编辑器开发计划
- 🔍 **[故障排除](./TROUBLESHOOTING.md)** - 问题诊断和解决
- 📘 **[API文档](./API_REFERENCE.md)** - RESTful API参考
- 🚀 **[部署指南](./DEPLOYMENT_GUIDE.md)** - 生产环境部署
- 🔐 **[安全指南](./SECURITY_GUIDE.md)** - 安全配置和最佳实践
- 🧪 **[测试指南](./TESTING_GUIDE.md)** - 测试策略和自动化
- 🏛️ **[系统架构](./ARCHITECTURE.md)** - 架构设计和技术选型
- 🔄 **[迁移指南](./MIGRATION_GUIDE.md)** - 版本升级和平台迁移
- 🤖 **[自动化部署](./AUTOMATED_DEPLOYMENT.md)** - CI/CD和自动化流程
- 📋 **[文档检查](./DOCUMENTATION_REVIEW.md)** - 文档质量评估

## 核心特性

### 🔧 配置管理
- **环境变量驱动**: 所有敏感信息通过环境变量管理
- **模板化配置**: YAML配置文件模板化，支持动态生成
- **验证机制**: 配置语法验证和参数检查
- **备份恢复**: 自动配置备份和版本控制

### 🔒 安全加固
- **非root用户**: 所有容器使用非特权用户运行
- **最小权限**: 实施Linux capabilities最小化
- **网络隔离**: 容器间网络隔离和端口绑定限制
- **访问控制**: HTTP基本认证和IP白名单

### 📊 监控系统
- **健康检查**: 多层次服务健康监控
- **性能指标**: 资源使用情况监控
- **日志聚合**: 统一日志收集和分析
- **告警机制**: 异常状态自动告警

### 🧪 测试框架
- **多层测试**: 单元测试、集成测试、端到端测试
- **自动化CI**: 完整的测试流水线
- **性能测试**: 负载测试和基准测试
- **安全扫描**: 自动化安全漏洞检测

## 项目结构

```
clash-docker/
├── config/                 # 配置文件目录
│   ├── config.yaml         # Clash主配置文件
│   └── template.yaml       # 配置模板文件
├── scripts/                # 工具脚本
│   ├── generate-config-advanced.sh    # 高级配置生成器
│   ├── validate-env.sh               # 环境变量验证
│   ├── health-check.sh              # 健康检查脚本
│   └── setup-environment.sh         # 环境初始化
├── security/               # 安全配置
│   ├── compose.secure.yml           # 安全加固的Docker配置
│   ├── nginx-security.conf         # Nginx安全配置
│   ├── docker-security-scan.sh     # 安全扫描工具
│   └── htpasswd                    # 认证文件
├── test-suite/            # 测试框架
│   ├── unit/              # 单元测试
│   ├── integration/       # 集成测试
│   ├── e2e/              # 端到端测试
│   └── performance/       # 性能测试
├── monitoring/            # 监控配置
│   ├── compose.monitoring.yml      # 监控服务配置
│   ├── grafana/                   # Grafana配置
│   └── prometheus/                # Prometheus配置
├── docs/                  # 文档目录
├── .env.example          # 环境变量示例
├── compose.yml           # 基础Docker Compose配置
├── compose.test.yml      # 测试环境配置
└── README.md            # 项目说明文档
```

## 快速开始

### 环境要求
- Docker Engine 20.10+
- Docker Compose 2.0+
- Linux/macOS/Windows (WSL2)
- 最少2GB内存，10GB磁盘空间

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd clash-docker
   ```

2. **配置环境变量**
   ```bash
   cp .env.example .env
   # 编辑 .env 文件，设置必要的配置参数
   nano .env
   ```

3. **初始化环境**
   ```bash
   ./scripts/setup-environment.sh
   ```

4. **启动服务**
   ```bash
   # 基础版本
   docker compose up -d
   
   # 安全加固版本
   docker compose -f security/compose.secure.yml up -d
   
   # 完整监控版本
   docker compose -f compose.yml -f monitoring/compose.monitoring.yml up -d
   ```

### 验证部署

```bash
# 检查服务状态
docker compose ps

# 运行健康检查
./scripts/health-check.sh

# 访问配置文件
curl http://localhost:8088/config.yaml

# 查看监控面板 (如果启用了监控)
open http://localhost:3000  # Grafana
```

## 配置说明

### 环境变量

#### 代理配置
```bash
# 代理端口配置
CLASH_HTTP_PORT=7890
CLASH_SOCKS_PORT=7891
CLASH_CONTROL_PORT=9090

# 代理节点配置
PROXY_SERVER_1=server1.example.com
PROXY_PORT_1=443
PROXY_PASSWORD_1=your_password_1
PROXY_CIPHER_1=aes-256-gcm

# 规则配置
CLASH_MODE=rule
CLASH_LOG_LEVEL=info
CLASH_ALLOW_LAN=false
```

#### 安全配置
```bash
# 认证配置
CLASH_SECRET=your_secret_key
NGINX_AUTH_USER=admin
NGINX_AUTH_PASS=secure_password

# 网络配置
NGINX_PORT=8088
BIND_ADDRESS=127.0.0.1
```

### 代理节点配置

支持多种代理协议：
- Shadowsocks
- VMess
- Trojan
- SOCKS5
- HTTP

详细配置请参考 [配置指南](./configuration.md)。

## 部署模式

### 开发环境
```bash
# 使用测试配置
docker compose -f compose.test.yml up -d
```

### 生产环境
```bash
# 使用安全加固配置
docker compose -f security/compose.secure.yml up -d
```

### 监控环境
```bash
# 启用完整监控
docker compose -f compose.yml -f monitoring/compose.monitoring.yml up -d
```

## 安全特性

### 网络安全
- 端口绑定到localhost，避免外部直接访问
- 网络隔离，容器间通信限制
- DDoS防护和限流机制
- 恶意请求检测和阻断

### 容器安全
- 非root用户运行所有服务
- 只读根文件系统
- Linux capabilities最小化
- 资源限制和隔离

### 访问控制
- HTTP基本认证
- IP地址白名单
- API访问令牌验证
- 审计日志记录

详细安全配置请参考 [安全指南](./SECURITY_GUIDE.md)。

## 监控和运维

### 健康检查
```bash
# 运行完整健康检查
./scripts/health-check.sh

# 检查特定服务
./scripts/health-check.sh services

# 检查系统资源
./scripts/health-check.sh containers
```

### 日志管理
```bash
# 查看服务日志
docker compose logs -f clash
docker compose logs -f nginx

# 查看健康检查日志
tail -f logs/health-check.log

# 查看安全监控日志
tail -f logs/security-monitor.log
```

### 性能监控
- **Grafana Dashboard**: 可视化监控面板
- **Prometheus Metrics**: 指标收集和存储
- **Alert Manager**: 告警管理
- **系统资源监控**: CPU、内存、磁盘、网络

## 测试和质量保证

### 运行测试
```bash
# 运行所有测试
./test-suite/run-all-tests.sh

# 运行特定测试类型
./test-suite/unit/run-tests.sh
./test-suite/integration/run-tests.sh
./test-suite/e2e/run-tests.sh
```

### 安全扫描
```bash
# 运行安全扫描
./security/docker-security-scan.sh

# 查看扫描结果
ls -la security/scan-results/
```

### 性能测试
```bash
# 运行性能基准测试
./test-suite/performance/benchmark.sh

# 负载测试
./test-suite/performance/load-test.sh
```

## 故障排除

### 常见问题

1. **容器启动失败**
   - 检查端口占用: `netstat -tlnp | grep :8088`
   - 检查环境变量: `./scripts/validate-env.sh`
   - 查看容器日志: `docker compose logs`

2. **配置文件错误**
   - 验证YAML语法: `python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"`
   - 重新生成配置: `./scripts/generate-config-advanced.sh`

3. **网络连接问题**
   - 检查防火墙设置
   - 验证代理节点可达性
   - 检查DNS解析

4. **权限问题**
   - 确认文件权限: `ls -la config/`
   - 检查用户映射: `id`

### 日志分析
```bash
# 查看错误日志
grep -i error logs/*.log

# 分析访问模式
awk '{print $1}' logs/nginx-access.log | sort | uniq -c | sort -nr

# 监控实时日志
tail -f logs/*.log
```

## 贡献指南

### 开发流程
1. 创建功能分支
2. 编写代码和测试
3. 运行完整测试套件
4. 提交Pull Request

### 代码规范
- Shell脚本使用shellcheck验证
- Docker配置遵循最佳实践
- 文档使用Markdown格式
- 提交信息遵循Conventional Commits

### 测试要求
- 新功能必须包含测试
- 测试覆盖率不低于80%
- 安全扫描必须通过
- 性能测试不能回退

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](../LICENSE) 文件。

## 支持和联系

- **文档**: [docs/](./)
- **问题报告**: [GitHub Issues](https://github.com/your-org/clash-docker/issues)
- **安全问题**: security@your-org.com

---

*最后更新: 2025-07-13*
*版本: 1.0.0*