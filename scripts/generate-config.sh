#!/bin/bash

# Clash配置生成脚本
# 从环境变量和模板生成最终的clash配置文件

set -e

CONFIG_TEMPLATE="config/clash-template.yaml"
CONFIG_OUTPUT="config/config.yaml"
ENV_FILE=".env"

echo "开始生成Clash配置文件..."

# 检查必要文件是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "错误: 未找到 .env 文件，请先从 .env.example 复制并配置"
    exit 1
fi

if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "错误: 未找到配置模板文件 $CONFIG_TEMPLATE"
    exit 1
fi

# 加载环境变量
set -a
source "$ENV_FILE"
set +a

# 创建配置目录
mkdir -p "$(dirname "$CONFIG_OUTPUT")"

echo "正在替换环境变量..."

# 使用envsubst替换环境变量
envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"

echo "Clash配置文件已生成: $CONFIG_OUTPUT"
echo "配置生成完成!"