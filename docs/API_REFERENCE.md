# 📘 API参考文档

## 📚 目录

1. [API概述](#api概述)
2. [认证机制](#认证机制)
3. [配置生成API](#配置生成api)
4. [模板管理API](#模板管理api)
5. [健康检查API](#健康检查api)
6. [系统监控API](#系统监控api)
7. [错误码定义](#错误码定义)
8. [请求响应示例](#请求响应示例)

---

## API概述

Clash Docker提供RESTful API接口，支持配置管理、健康检查和系统监控等功能。

**基础URL**: `http://localhost:8088/api/v1`
**认证方式**: HTTP Basic Auth (可选)
**数据格式**: JSON

## 认证机制

### HTTP Basic Authentication

如果启用了认证（`NGINX_AUTH_ENABLED=true`），所有API请求需要包含认证头：

```bash
curl -u ${NGINX_AUTH_USER}:${NGINX_AUTH_PASS} \
  http://localhost:8088/api/v1/config
```

### API Token (规划中)

未来版本将支持Bearer Token认证方式。

## 配置生成API

### 生成Clash配置

**端点**: `POST /config/generate`

**描述**: 基于环境变量生成Clash配置文件

**请求体**:
```json
{
  "template": "default",
  "format": "yaml",
  "validate": true
}
```

**响应**:
```json
{
  "status": "success",
  "data": {
    "config": "port: 7890\nsocks-port: 7891\n...",
    "hash": "sha256:abc123...",
    "generated_at": "2025-07-13T14:48:30Z"
  }
}
```

### 获取当前配置

**端点**: `GET /config`

**描述**: 获取当前生效的Clash配置

**响应**:
```json
{
  "status": "success",
  "data": {
    "config": "...",
    "version": "1.0.0",
    "last_modified": "2025-07-13T14:48:30Z"
  }
}
```

### 验证配置

**端点**: `POST /config/validate`

**描述**: 验证YAML配置文件的语法和内容

**请求体**:
```json
{
  "config": "port: 7890\nsocks-port: 7891\n..."
}
```

**响应**:
```json
{
  "status": "success",
  "data": {
    "valid": true,
    "errors": [],
    "warnings": ["建议设置更强的密码"]
  }
}
```

## 模板管理API

### 获取模板列表

**端点**: `GET /templates`

**描述**: 获取所有可用的配置模板

**响应**:
```json
{
  "status": "success",
  "data": {
    "templates": [
      {
        "name": "default",
        "description": "默认配置模板",
        "version": "1.0.0",
        "type": "main"
      },
      {
        "name": "rules-template",
        "description": "分离式规则模板",
        "version": "1.0.0",
        "type": "rules"
      }
    ]
  }
}
```

### 获取特定模板

**端点**: `GET /templates/{name}`

**描述**: 获取指定模板的内容

**响应**:
```json
{
  "status": "success",
  "data": {
    "name": "default",
    "content": "port: ${CLASH_HTTP_PORT}\n...",
    "variables": ["CLASH_HTTP_PORT", "PROXY_SERVER_1"],
    "last_modified": "2025-07-13T14:48:30Z"
  }
}
```

### 更新模板

**端点**: `PUT /templates/{name}`

**描述**: 更新指定模板的内容

**请求体**:
```json
{
  "content": "port: ${CLASH_HTTP_PORT}\n...",
  "description": "更新后的模板描述"
}
```

**响应**:
```json
{
  "status": "success",
  "message": "模板更新成功"
}
```

## 健康检查API

### 系统健康检查

**端点**: `GET /health`

**描述**: 检查系统整体健康状态

**响应**:
```json
{
  "status": "healthy",
  "timestamp": "2025-07-13T14:48:30Z",
  "services": {
    "clash": "healthy",
    "nginx": "healthy",
    "config-generator": "healthy"
  },
  "version": "1.0.0"
}
```

### 详细健康检查

**端点**: `GET /health/detailed`

**描述**: 获取详细的健康检查信息

**响应**:
```json
{
  "status": "healthy",
  "timestamp": "2025-07-13T14:48:30Z",
  "services": {
    "clash": {
      "status": "healthy",
      "port": 7890,
      "response_time": "15ms",
      "memory_usage": "45MB"
    },
    "nginx": {
      "status": "healthy",
      "port": 8088,
      "response_time": "5ms"
    }
  },
  "system": {
    "cpu_usage": "12%",
    "memory_usage": "256MB",
    "disk_usage": "2.1GB"
  }
}
```

## 系统监控API

### 获取系统指标

**端点**: `GET /metrics`

**描述**: 获取系统性能指标

**响应**:
```json
{
  "status": "success",
  "data": {
    "cpu_usage": 12.5,
    "memory_usage": {
      "total": "2GB",
      "used": "256MB",
      "percentage": 12.5
    },
    "network": {
      "bytes_in": 1024000,
      "bytes_out": 512000
    },
    "connections": {
      "active": 25,
      "total": 1024
    }
  }
}
```

### 获取日志

**端点**: `GET /logs`

**描述**: 获取系统日志

**查询参数**:
- `service`: 服务名称 (clash, nginx, config-generator)
- `level`: 日志级别 (debug, info, warn, error)
- `limit`: 返回条数限制 (默认100)
- `since`: 起始时间 (ISO8601格式)

**响应**:
```json
{
  "status": "success",
  "data": {
    "logs": [
      {
        "timestamp": "2025-07-13T14:48:30Z",
        "level": "info",
        "service": "clash",
        "message": "HTTP proxy started at :7890"
      }
    ],
    "total": 1,
    "has_more": false
  }
}
```

## 错误码定义

### HTTP状态码

| 状态码 | 描述 | 示例场景 |
|--------|------|----------|
| 200 | 成功 | 正常请求完成 |
| 201 | 创建成功 | 配置文件生成成功 |
| 400 | 请求错误 | 参数格式错误 |
| 401 | 认证失败 | 认证信息错误或缺失 |
| 403 | 权限不足 | 访问被拒绝 |
| 404 | 资源不存在 | 模板或配置文件不存在 |
| 422 | 验证失败 | 配置内容验证失败 |
| 500 | 服务器错误 | 内部处理错误 |
| 503 | 服务不可用 | 依赖服务异常 |

### 应用错误码

| 错误码 | 描述 | 解决方案 |
|--------|------|----------|
| E1001 | 配置模板不存在 | 检查模板名称是否正确 |
| E1002 | 环境变量缺失 | 设置必需的环境变量 |
| E1003 | YAML语法错误 | 检查YAML格式 |
| E1004 | 配置验证失败 | 检查配置内容的有效性 |
| E1005 | 文件权限错误 | 检查文件访问权限 |
| E2001 | Clash服务异常 | 检查Clash服务状态 |
| E2002 | 网络连接失败 | 检查网络配置 |
| E3001 | 系统资源不足 | 释放系统资源 |

## 请求响应示例

### 生成配置文件示例

**请求**:
```bash
curl -X POST http://localhost:8088/api/v1/config/generate \
  -H "Content-Type: application/json" \
  -d '{
    "template": "default",
    "format": "yaml",
    "validate": true
  }'
```

**成功响应**:
```json
{
  "status": "success",
  "data": {
    "config": "port: 7890\nsocks-port: 7891\nallow-lan: false\nmode: rule\nlog-level: info\nexternal-controller: 127.0.0.1:9090\nsecret: \"your_secret_key\"\nproxies:\n  - name: \"节点1\"\n    type: ss\n    server: server1.example.com\n    port: 443\n    cipher: aes-256-gcm\n    password: \"your_password\"\nproxy-groups:\n  - name: \"PROXY\"\n    type: select\n    proxies:\n      - \"节点1\"\n      - \"DIRECT\"\nrules:\n  - GEOIP,CN,DIRECT\n  - MATCH,PROXY",
    "hash": "sha256:a1b2c3d4e5f6789...",
    "generated_at": "2025-07-13T14:48:30Z"
  }
}
```

**错误响应**:
```json
{
  "status": "error",
  "error": {
    "code": "E1002",
    "message": "缺少必需的环境变量: PROXY_SERVER_1",
    "details": {
      "missing_variables": ["PROXY_SERVER_1", "PROXY_PASSWORD_1"]
    }
  }
}
```

### 健康检查示例

**请求**:
```bash
curl http://localhost:8088/api/v1/health
```

**响应**:
```json
{
  "status": "healthy",
  "timestamp": "2025-07-13T14:48:30Z",
  "services": {
    "clash": "healthy",
    "nginx": "healthy",
    "config-generator": "healthy"
  },
  "version": "1.0.0",
  "uptime": "2h 30m 15s"
}
```

---

**更新日期**: 2025-07-13  
**API版本**: v1.0.0  
**维护者**: Clash Docker Team