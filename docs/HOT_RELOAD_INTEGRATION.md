# 🔄 热重载服务集成说明

## 概述

热重载服务已成功集成到主 `compose.yml` 文件中，现在作为 Clash Docker 项目的核心组件运行。

## 🔄 主要变更

### 1. 主 compose 文件集成
- **热重载服务**已添加到 `compose.yml` 中
- **不再需要**单独的 `docker-compose.hot-reload.yml` 文件
- 所有服务现在通过**单一 compose 文件**管理

### 2. 服务依赖关系
```yaml
hot-reload:
  depends_on:
    clash:
      condition: service_healthy
    nginx:
      condition: service_started
```

### 3. 健康检查
为 `clash` 服务添加了健康检查：
```yaml
clash:
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9090/traffic -H 'Authorization: Bearer ${CLASH_SECRET}' || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

### 4. 环境变量配置
在 `.env` 文件中新增热重载配置：
```bash
# Hot Reload Configuration
HOT_RELOAD_PORT=8081
HOT_RELOAD_DEBOUNCE_TIME=2000
HOT_RELOAD_STRATEGY=selective
HOT_RELOAD_MAX_RESTART_TIME=60000
HOT_RELOAD_HEALTH_CHECK_TIMEOUT=30000
HOT_RELOAD_CORS_ORIGIN=*
```

## 🚀 使用方法

### 启动所有服务（包括热重载）
```bash
# 使用更新后的启动脚本
./scripts/start-hot-reload.sh

# 或直接使用 docker-compose
docker-compose up -d
```

### 查看服务状态
```bash
docker-compose ps
```

### 查看热重载日志
```bash
docker-compose logs -f hot-reload
```

### 停止所有服务
```bash
docker-compose down
```

## 📊 服务端点

| 服务 | 端口 | 用途 |
|-----|------|------|
| Clash HTTP | 7890 | HTTP 代理 |
| Clash SOCKS | 7891 | SOCKS 代理 |
| Clash Control | 9090 | 管理接口 |
| Nginx Web | 8088 | Web 界面 |
| **Hot Reload API** | **8081** | **热重载 HTTP API** |
| **Hot Reload WebSocket** | **8081** | **实时状态推送** |

## 🔧 配置文件监控

热重载服务监控以下文件：
- `.env` - 环境变量配置
- `config/config.yaml` - Clash 配置文件
- `config/rules/` - 规则文件目录
- `config/templates/` - 模板文件目录

## ⚡ 重启策略

- **Critical 变更**: 全量重启所有服务
- **Moderate 变更**: 选择性重启受影响的服务
- **Minor 变更**: 仅重载配置（发送 SIGHUP 信号）

## 🔍 健康检查

所有服务现在都有适当的健康检查：
- **Clash**: 通过 API 端点检查
- **Hot Reload**: 通过 `/health` 端点检查
- **依赖关系**: 确保服务按正确顺序启动

## 📁 文件结构

```
├── compose.yml                     # 主 compose 文件（包含热重载）
├── docker-compose.hot-reload.yml   # 已弃用，可删除
├── .env                            # 包含热重载配置
├── scripts/
│   └── start-hot-reload.sh         # 更新后的启动脚本
└── services/
    └── hot-reload/                 # 热重载服务源码
```

## 🎯 优势

1. **统一管理**: 所有服务在一个 compose 文件中
2. **简化部署**: 一个命令启动完整系统
3. **依赖控制**: 正确的服务启动顺序
4. **健康监控**: 完整的健康检查体系
5. **配置集中**: 环境变量统一管理

## 🔄 迁移说明

如果之前使用独立的热重载 compose 文件：
1. 停止旧服务：`docker-compose -f docker-compose.hot-reload.yml down`
2. 使用新方式：`./scripts/start-hot-reload.sh`
3. 可选择删除：`docker-compose.hot-reload.yml`

## 🚨 注意事项

- 确保 `.env` 文件包含所有必要的热重载配置
- 热重载服务需要访问 Docker Socket
- 首次启动可能需要较长时间构建镜像

## 🔧 故障排除

### 常见问题

1. **端口冲突**
   - 问题：`port 8080 already in use`
   - 解决：修改 `.env` 中的 `HOT_RELOAD_PORT=8081`

2. **Clash 配置错误**
   - 问题：`invalid mode: redir-host`
   - 解决：已修复配置模板使用 `fake-ip` 模式

3. **依赖服务未启动**
   - 问题：`container is unhealthy`
   - 解决：已调整依赖关系，无需等待健康检查

### 验证服务状态

```bash
# 检查所有服务状态
sudo docker-compose ps

# 验证热重载服务
curl http://localhost:8081/health

# 查看监控的文件路径
curl http://localhost:8081/api/watched-paths

# 查看热重载日志
sudo docker-compose logs -f hot-reload
```

---

**文档版本**: v1.1.0  
**最后更新**: 2025-07-13  
**作者**: Clash Docker 开发团队