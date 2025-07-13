#!/bin/bash

# Docker镜像构建和推送脚本
# 用于本地开发和CI/CD环境

set -euo pipefail

# 配置常量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="${IMAGE_NAME:-clash-docker-config-generator}"
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-$(whoami)}"
TAG="${TAG:-latest}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
    --image-name NAME     镜像名称 (默认: clash-docker-config-generator)
    --registry REGISTRY   镜像仓库 (默认: ghcr.io)
    --namespace NAMESPACE 命名空间 (默认: 当前用户名)
    --tag TAG            镜像标签 (默认: latest)
    --platform PLATFORM  目标平台 (如: linux/amd64,linux/arm64)
    --push               构建后推送到仓库
    --no-cache           不使用缓存构建
    --dry-run            仅显示将要执行的命令
    --help               显示此帮助信息

环境变量:
    IMAGE_NAME           镜像名称
    REGISTRY             镜像仓库
    NAMESPACE            命名空间
    TAG                  镜像标签
    DOCKER_BUILDKIT      启用BuildKit (推荐设置为1)

示例:
    $0 --push
    $0 --tag v1.0.0 --push
    $0 --platform linux/amd64,linux/arm64 --push
    $0 --namespace myorg --registry docker.io --push

EOF
}

# 检查Docker环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或不在PATH中"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "无法连接到Docker守护进程"
        exit 1
    fi
    
    log_success "Docker环境检查通过"
}

# 构建镜像
build_image() {
    local full_image_name="$REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
    local build_args=()
    
    log_info "准备构建镜像: $full_image_name"
    
    # 构建参数
    build_args+=("--file" "$PROJECT_DIR/dockerfiles/Dockerfile.config-generator")
    build_args+=("--tag" "$full_image_name")
    
    if [[ "${PLATFORM:-}" != "" ]]; then
        build_args+=("--platform" "$PLATFORM")
    fi
    
    if [[ "${NO_CACHE:-false}" == "true" ]]; then
        build_args+=("--no-cache")
    fi
    
    # 添加构建标签
    build_args+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    build_args+=("--label" "org.opencontainers.image.source=https://github.com/$NAMESPACE/clash-docker")
    build_args+=("--label" "org.opencontainers.image.version=$TAG")
    build_args+=("--label" "org.opencontainers.image.revision=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')")
    
    log_info "构建命令: docker build ${build_args[*]} $PROJECT_DIR"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: 将执行上述构建命令"
        return 0
    fi
    
    # 执行构建
    if docker build "${build_args[@]}" "$PROJECT_DIR"; then
        log_success "镜像构建成功: $full_image_name"
        
        # 显示镜像信息
        docker images "$full_image_name" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 推送镜像
push_image() {
    local full_image_name="$REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
    
    log_info "准备推送镜像: $full_image_name"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: docker push $full_image_name"
        return 0
    fi
    
    if docker push "$full_image_name"; then
        log_success "镜像推送成功: $full_image_name"
    else
        log_error "镜像推送失败"
        exit 1
    fi
}

# 安全扫描
security_scan() {
    local full_image_name="$REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
    
    log_info "对镜像进行安全扫描..."
    
    if command -v trivy &> /dev/null; then
        log_info "使用Trivy进行安全扫描"
        trivy image "$full_image_name" || log_warn "安全扫描发现问题，请检查报告"
    else
        log_warn "Trivy未安装，跳过安全扫描"
    fi
}

# 主函数
main() {
    local PUSH=false
    local NO_CACHE=false
    local DRY_RUN=false
    local SCAN=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image-name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --tag)
                TAG="$2"
                shift 2
                ;;
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            --push)
                PUSH=true
                shift
                ;;
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --scan)
                SCAN=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 环境变量
    export NO_CACHE DRY_RUN
    
    log_info "构建配置:"
    log_info "  镜像名称: $IMAGE_NAME"
    log_info "  仓库地址: $REGISTRY"
    log_info "  命名空间: $NAMESPACE"
    log_info "  镜像标签: $TAG"
    log_info "  推送镜像: $PUSH"
    log_info "  安全扫描: $SCAN"
    
    # 执行构建流程
    check_docker
    build_image
    
    if [[ "$SCAN" == "true" ]]; then
        security_scan
    fi
    
    if [[ "$PUSH" == "true" ]]; then
        push_image
    fi
    
    log_success "构建流程完成!"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi