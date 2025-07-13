# 更新日志

## [1.1.0] - 2025-07-13

### 🚀 新增功能

#### CI/CD 集成
- 添加完整的 GitHub Actions CI/CD 工作流
  - 代码质量检查 (ShellCheck)
  - 安全扫描 (Trivy)
  - 配置验证测试
  - Docker 镜像构建和推送
  - 集成测试
  - 自动化部署支持

#### 安全增强
- 新增 `SECURITY.md` 安全策略文件
- 集成 Dependabot 自动依赖更新
- 定期安全扫描工作流
- 增强的安全扫描脚本

#### 构建优化
- 为 config-generator 创建专用 Dockerfile
- 新增构建和推送脚本 (`scripts/build-and-push.sh`)
- 支持多平台构建 (amd64/arm64)

### 🔧 改进

#### 依赖管理
- **重要**: 所有 Docker 镜像版本固定
  - `dreamacro/clash:latest` → `dreamacro/clash:v1.18.0`
  - `nginx:alpine` → `nginx:1.25.3-alpine`
  - `alpine:latest` → `alpine:3.18.3`

#### 配置管理
- config-generator 不再运行时安装依赖
- 预构建镜像包含所有必要依赖
- 提升启动速度和可靠性

#### 安全配置
- 更新 `security/compose.secure.yml` 使用固定版本镜像
- 使用预构建的 config-generator 镜像

### 📁 新增文件

```
.github/
├── workflows/
│   ├── ci-cd.yml              # 主 CI/CD 工作流
│   └── security-scan.yml      # 安全扫描工作流
└── dependabot.yml             # Dependabot 配置

dockerfiles/
└── Dockerfile.config-generator # config-generator 专用 Dockerfile

scripts/
└── build-and-push.sh          # 镜像构建脚本

SECURITY.md                    # 安全策略文档
CHANGELOG.md                   # 更新日志
```

### 🛠️ 技术改进

1. **构建可复现性**: 固定版本确保每次构建结果一致
2. **启动性能**: 预构建镜像减少启动时间
3. **安全性**: 定期扫描和依赖更新
4. **可维护性**: CI/CD 自动化减少手动操作

### 📋 迁移指南

#### 更新现有部署

1. **备份当前配置**:
   ```bash
   cp compose.yml compose.yml.backup
   ```

2. **使用新配置**:
   ```bash
   # 停止服务
   docker compose down
   
   # 拉取最新代码
   git pull origin main
   
   # 重新构建并启动
   docker compose build
   docker compose up -d
   ```

3. **验证服务**:
   ```bash
   docker compose ps
   docker compose logs
   ```

#### 安全部署

推荐生产环境使用安全配置：
```bash
docker compose -f security/compose.secure.yml up -d
```

### ⚠️ 重要说明

- **版本锁定**: 镜像版本已固定，需要手动更新版本号
- **构建变化**: config-generator 现在需要先构建镜像
- **安全增强**: 建议生产环境使用 `security/compose.secure.yml`

### 🔍 安全检查

运行以下命令进行安全检查：
```bash
# 环境变量验证
./scripts/validate-env.sh .env

# 配置生成测试
./scripts/debug-config.sh test .env

# Docker 安全扫描
./security/docker-security-scan.sh
```

### 📚 文档更新

- 新增安全策略文档
- 更新 CI/CD 工作流说明
- 添加构建和部署指南

---

## [1.0.0] - 2025-07-12

### 初始版本
- 基础 Clash Docker 配置
- 环境变量管理
- 配置生成脚本
- 安全加固选项