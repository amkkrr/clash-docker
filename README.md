# Clash Docker with Nginx

使用环境变量管理密码的 Clash + Nginx Docker Compose 配置。

## 快速开始

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

## 服务说明

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

## 常用命令

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

## 配置文件

- `compose.yml`: Docker Compose 主配置
- `.env`: 环境变量配置 (需要创建)
- `.env.example`: 环境变量模板
- `config/clash-template.yaml`: Clash 配置模板
- `config/config.yaml`: 生成的 Clash 配置文件 (自动生成)
- `scripts/generate-config.sh`: 配置生成脚本
- `nginx.conf`: Nginx 配置
- `.gitignore`: Git 忽略文件

## 配置说明

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

## 安全注意事项

- 确保 `.env` 文件不会被提交到版本控制
- 使用强密码作为 `CLASH_SECRET`
- 考虑在生产环境中使用 HTTPS
- 定期更新 Docker 镜像