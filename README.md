# 🚀 Clash Docker 企业级解决方案

[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/your-org/clash-docker)](https://github.com/your-org/clash-docker/issues)
[![Development Status](https://img.shields.io/badge/Development-Active-green.svg)](https://github.com/your-org/clash-docker)
[![Documentation](https://img.shields.io/badge/Documentation-Complete-brightgreen.svg)](docs/README.md)

一个功能完整、安全可靠的 Clash 代理服务 Docker 解决方案，集成环境变量管理、配置模板化、安全加固和监控系统。

## ✨ 核心特性

- 🔒 **环境变量管理**: 敏感信息通过环境变量隔离
- 📝 **模板化配置**: 支持YAML模板和分离式规则管理
- 🔐 **安全加固**: 非root运行、访问控制、审计日志
- 📊 **监控系统**: 健康检查、性能指标、日志聚合
- 🧪 **测试框架**: 完整的单元测试、集成测试、E2E测试
- 🏗️ **CI/CD集成**: 自动化构建、测试、部署流水线

## 📈 开发进度

### 🎯 项目状态

| 模块 | 状态 | 进度 | 最后更新 |
|------|------|------|----------|
| **核心功能** | ✅ 完成 | 100% | 2025-07-13 |
| **Docker集成** | ✅ 完成 | 100% | 2025-07-13 |
| **配置管理** | ✅ 完成 | 100% | 2025-07-13 |
| **安全加固** | ✅ 完成 | 100% | 2025-07-13 |
| **监控系统** | ✅ 完成 | 100% | 2025-07-13 |
| **测试框架** | ✅ 完成 | 100% | 2025-07-13 |
| **文档体系** | ✅ 完成 | 100% | 2025-07-13 |
| **CI/CD流程** | ✅ 完成 | 100% | 2025-07-13 |
| **可视化编辑器** | 🚧 规划中 | 15% | 2025-07-13 |

### 🗓️ 开发里程碑

- **v1.0.0** ✅ 基础功能完成 (2025-07-13)
  - Docker容器化部署
  - 环境变量配置管理
  - 基础安全加固
  - 完整文档体系

- **v1.1.0** 🚧 增强功能开发中
  - 可视化配置编辑器
  - 高级监控仪表板
  - 性能优化
  - 用户界面改进

- **v2.0.0** 📋 计划中
  - 微服务架构重构
  - Kubernetes支持
  - 多租户管理
  - 企业级集成

### 🔄 当前开发重点

1. **可视化编辑器** (进行中)
   - 📋 [前端开发计划](docs/FRONTEND_DEVELOPMENT_PLAN.md) 已完成
   - 🎨 UI/UX设计规划中
   - ⚙️ 后端API开发准备中

2. **性能优化** (规划中)
   - 容器资源优化
   - 网络性能调优
   - 缓存策略改进

3. **用户体验提升** (规划中)
   - Web管理界面
   - 实时状态监控
   - 配置向导功能

## 📚 文档导航

- 📖 **[完整文档](docs/README.md)** - 企业级部署指南
- 🔧 **[配置指南](docs/configuration.md)** - 详细配置说明
- 🏗️ **[前端开发](docs/FRONTEND_DEVELOPMENT_PLAN.md)** - 可视化编辑器开发计划
- 🔍 **[故障排除](docs/TROUBLESHOOTING.md)** - 问题诊断和解决
- 📘 **[API文档](docs/API_REFERENCE.md)** - RESTful API参考
- 🚀 **[部署指南](docs/DEPLOYMENT_GUIDE.md)** - 生产环境部署
- 🔐 **[安全指南](docs/SECURITY_GUIDE.md)** - 安全配置和最佳实践
- 🧪 **[测试指南](docs/TESTING_GUIDE.md)** - 测试策略和自动化
- 🏛️ **[系统架构](docs/ARCHITECTURE.md)** - 架构设计和技术选型
- 🔄 **[迁移指南](docs/MIGRATION_GUIDE.md)** - 版本升级和平台迁移
- 🤖 **[自动化部署](docs/AUTOMATED_DEPLOYMENT.md)** - CI/CD和自动化流程
- 📋 **[文档检查](docs/DOCUMENTATION_REVIEW.md)** - 文档质量评估

## 🚀 快速开始

### 一键设置（推荐）
```bash
./scripts/setup.sh
```

### 手动设置
1. **复制环境变量模板**
   ```bash
   cp .env.example .env
   ```

2. **编辑环境变量**
   ```bash
   nano .env
   ```
   配置所有代理服务器信息，包括：
   - Clash 基础配置（密码、端口等）
   - 各个代理服务器的地址、端口、密码等敏感信息
   - 示例配置已经在 `.env.example` 中详细列出

3. **创建必要目录**
   ```bash
   mkdir -p config data html scripts
   ```

4. **启动服务**
   ```bash
   docker compose up -d
   ```
   
   系统会自动：
   - 从环境变量和模板生成 Clash 配置文件
   - 启动 Clash 代理服务
   - 启动 Nginx 反向代理

5. **访问服务**
   ```
   http://localhost/config.yaml    # Clash配置文件订阅地址
   http://localhost/               # 配置服务首页
   http://localhost/dashboard/     # 管理界面
   http://localhost/api/           # Clash API代理
   ```

## 🏗️ 项目架构

```
Clash Docker 解决方案
├── 🐳 Docker 服务
│   ├── Clash Core (代理核心)
│   ├── Nginx (Web服务)
│   └── Config Generator (配置生成)
├── 📁 配置管理
│   ├── 环境变量 (.env)
│   ├── 主模板 (clash-template.yaml)
│   └── 规则模板 (rules-template.yaml)
├── 🔒 安全层
│   ├── HTTP认证
│   ├── IP白名单
│   └── 非root运行
└── 📊 监控层
    ├── 健康检查
    ├── 指标收集
    └── 日志聚合
```

## 🐳 服务说明

### Clash
- HTTP 代理端口: `7890` (可配置)
- SOCKS 代理端口: `7891` (可配置)  
- 控制端口: `9090` (可配置)
- 配置目录: `./config`
- 数据目录: `./data`

### Nginx配置服务器
- Web 端口: `80` (可配置)
- **主要功能**: 提供纯净的YAML配置文件访问
- 支持 CORS 跨域访问（用于订阅更新）
- 正确的MIME类型设置 (`text/yaml`)

### 访问路径说明
- **`/config.yaml`**: 纯净的Clash配置文件，可直接被Clash客户端解析
- **`/`**: 配置服务首页，显示订阅地址和使用说明
- **`/dashboard/`**: 管理界面入口，包含外部Dashboard链接
- **`/api/`**: Clash API反向代理，用于管理功能
- **`/health`**: 健康检查接口

### 订阅更新
- **订阅地址**: `http://localhost/config.yaml`
- **更新方式**: 客户端可定期GET请求获取最新配置
- **响应格式**: 标准的Clash YAML配置文件
- **MIME类型**: `text/yaml; charset=utf-8`

## 🔧 管理接口

### Web界面
- **主页**: http://localhost:8088/ - 服务状态和订阅地址
- **配置订阅**: http://localhost:8088/config.yaml - Clash配置文件
- **API接口**: http://localhost:8088/api/v1/ - RESTful API
- **健康检查**: http://localhost:8088/health - 服务健康状态

### Clash原生接口
- **控制面板**: http://localhost:9090/ - Clash内置API
- **代理状态**: http://localhost:9090/proxies - 节点状态
- **规则管理**: http://localhost:9090/rules - 规则配置

## 💻 常用命令

```bash
# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 更新镜像
docker compose pull && docker compose up -d
```

## 📊 运维监控

### 健康检查
```bash
# 完整健康检查
./scripts/health-check.sh

# 服务状态检查
./scripts/health-check.sh services

# 容器资源检查
./scripts/health-check.sh containers
```

### 日志管理
```bash
# 查看实时日志
docker compose logs -f

# 查看特定服务日志
docker compose logs clash
docker compose logs nginx

# 查看配置生成日志
tail -f logs/config-generation.log
```

### 性能监控
```bash
# 系统资源使用
docker stats

# 网络连接状态
netstat -tlnp | grep -E ':(7890|7891|8088|9090)'

# 代理节点延迟测试
curl http://localhost:9090/proxies/节点名/delay?timeout=5000&url=http://www.gstatic.com/generate_204
```

## 📁 配置文件

- `compose.yml`: Docker Compose 主配置
- `.env`: 环境变量配置 (需要创建)
- `.env.example`: 环境变量模板
- `config/clash-template.yaml`: Clash 配置模板
- `config/config.yaml`: 生成的 Clash 配置文件 (自动生成)
- `scripts/generate-config.sh`: 配置生成脚本
- `nginx.conf`: Nginx 配置
- `.gitignore`: Git 忽略文件

## ⚙️ 配置说明

### 敏感信息管理
所有敏感信息已从原始 `clash.yaml` 抽离到环境变量：

**代理配置类：**
- 代理服务器地址和端口
- 各种协议的密码 (hysteria2, shadowsocks, vmess, vless)
- UUID 和路径等认证信息

**Rules规则类：**
- 私有域名和服务域名
- 内部网络IP地址和IP段
- 香港节点相关IP和域名
- 特殊服务域名配置

### 配置生成流程
1. `config-generator` 容器启动时自动运行
2. 读取 `.env` 文件中的环境变量
3. 使用 `envsubst` 替换 `clash-template.yaml` 中的变量
4. 生成最终的 `config/config.yaml` 配置文件
5. Clash 容器启动并使用生成的配置

## 🔒 安全特性

### 容器安全
- **非root运行**: 所有容器使用非特权用户
- **最小权限**: Linux capabilities最小化
- **只读文件系统**: 防止运行时文件修改
- **资源限制**: CPU和内存使用限制

### 网络安全
- **端口绑定**: 默认绑定localhost，避免外部直接访问
- **访问控制**: HTTP基本认证和IP白名单
- **流量监控**: 访问日志和异常检测
- **DDoS防护**: 请求限流和连接数限制

### 数据安全
- **环境变量隔离**: 敏感信息不在配置文件中硬编码
- **配置模板**: 支持动态配置生成
- **审计日志**: 完整的操作记录
- **定期备份**: 自动配置备份和版本控制

## 🧪 测试和质量保证

### 自动化测试
```bash
# 运行完整测试套件
./test-suite/run-all-tests.sh

# 单元测试
./test-suite/unit/run-tests.sh

# 集成测试
./test-suite/integration/run-tests.sh

# 端到端测试
./test-suite/e2e/run-tests.sh
```

### 安全扫描
```bash
# Docker安全扫描
./security/docker-security-scan.sh

# 查看扫描结果
ls -la security/scan-results/
```

### 代码质量
- **Shell脚本**: Shellcheck静态分析
- **YAML配置**: yamllint语法检查
- **Docker配置**: Hadolint最佳实践检查

## 🚀 部署选项

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

### 完整监控
```bash
# 启用Grafana + Prometheus监控
docker compose -f compose.yml -f monitoring/compose.monitoring.yml up -d
```

## 🤝 贡献指南

### 开发流程
1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 编写代码和测试
4. 运行完整测试套件
5. 提交更改 (`git commit -m 'Add amazing feature'`)
6. 推送分支 (`git push origin feature/amazing-feature`)
7. 创建 Pull Request

### 代码规范
- 遵循项目现有的代码风格
- 确保所有测试通过
- 添加必要的文档和注释
- 遵循 [Conventional Commits](https://www.conventionalcommits.org/) 提交格式

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 📊 项目统计

![GitHub last commit](https://img.shields.io/github/last-commit/your-org/clash-docker)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/your-org/clash-docker)
![GitHub contributors](https://img.shields.io/github/contributors/your-org/clash-docker)
![GitHub code size](https://img.shields.io/github/languages/code-size/your-org/clash-docker)

### 📈 开发活跃度

- **最后提交**: ![GitHub last commit](https://img.shields.io/github/last-commit/your-org/clash-docker?style=flat-square)
- **本月提交**: ![GitHub commit activity](https://img.shields.io/github/commit-activity/m/your-org/clash-docker?style=flat-square)
- **活跃贡献者**: ![GitHub contributors](https://img.shields.io/github/contributors/your-org/clash-docker?style=flat-square)
- **当前版本**: v1.0.0
- **下个里程碑**: v1.1.0 (可视化编辑器)

## 📞 支持和联系

- 📖 **文档**: [docs/](docs/)
- 🐛 **问题报告**: [GitHub Issues](https://github.com/your-org/clash-docker/issues)
- 🔒 **安全问题**: security@your-org.com
- 💬 **讨论**: [GitHub Discussions](https://github.com/your-org/clash-docker/discussions)
- 📈 **开发进度**: [项目看板](https://github.com/your-org/clash-docker/projects)

---

**⭐ 如果这个项目对你有帮助，请给我们一个星标！**

<!-- 开发进度徽章，自动更新 -->
[![GitHub release](https://img.shields.io/github/v/release/your-org/clash-docker)](https://github.com/your-org/clash-docker/releases)
[![GitHub milestone](https://img.shields.io/github/milestones/progress/your-org/clash-docker/1)](https://github.com/your-org/clash-docker/milestones)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/your-org/clash-docker)](https://github.com/your-org/clash-docker/pulls)