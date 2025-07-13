FROM node:18-alpine AS builder

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# 复制源代码和配置
COPY src/ ./src/
COPY tsconfig.json ./

# 安装开发依赖并编译TypeScript
RUN npm install --only=dev && npm run build && npm prune --production

FROM node:18-alpine AS runtime

WORKDIR /app

# 创建非特权用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# 创建日志目录
RUN mkdir -p /app/logs && \
    chown -R nodejs:nodejs /app/logs

# 复制编译后的代码和依赖
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# 安装健康检查工具
RUN apk add --no-cache curl

# 切换到非特权用户
USER nodejs

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 启动命令
CMD ["node", "dist/app.js"]