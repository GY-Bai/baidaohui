#!/bin/bash

# AI代理服务部署脚本
# 用于构建和部署AI代理服务到圣何塞VPS

set -e

echo "🤖 开始部署AI代理服务..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SERVICE_NAME="ai-proxy-service"
DOCKER_IMAGE="baidaohui/${SERVICE_NAME}:latest"
CONTAINER_NAME="ai-proxy-service"
SERVICE_PORT="5012"

echo -e "${BLUE}📋 服务信息:${NC}"
echo -e "  服务名称: ${SERVICE_NAME}"
echo -e "  Docker镜像: ${DOCKER_IMAGE}"
echo -e "  容器名称: ${CONTAINER_NAME}"
echo -e "  服务端口: ${SERVICE_PORT}"
echo ""

# 检查必需的环境变量
check_env_vars() {
    echo -e "${YELLOW}🔍 检查环境变量...${NC}"
    
    local required_vars=(
        "OPENROUTER_API_KEY"
        "MONGODB_URI"
        "JWT_SECRET"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        else
            echo -e "  ✅ ${var}: 已设置"
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo -e "${RED}❌ 缺少必需的环境变量:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "  - ${var}"
        done
        echo ""
        echo -e "${YELLOW}💡 请在 .env 文件中设置这些变量或在运行前导出它们${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 所有必需的环境变量已设置${NC}"
    echo ""
}

# 构建Docker镜像
build_image() {
    echo -e "${YELLOW}🔨 构建Docker镜像...${NC}"
    
    cd services/ai-proxy-service
    
    if docker build -t "${DOCKER_IMAGE}" .; then
        echo -e "${GREEN}✅ Docker镜像构建成功${NC}"
    else
        echo -e "${RED}❌ Docker镜像构建失败${NC}"
        exit 1
    fi
    
    cd ../../
    echo ""
}

# 停止现有容器
stop_existing() {
    echo -e "${YELLOW}🛑 停止现有容器...${NC}"
    
    if docker ps -q -f name="${CONTAINER_NAME}" | grep -q .; then
        echo "  停止容器: ${CONTAINER_NAME}"
        docker stop "${CONTAINER_NAME}"
    fi
    
    if docker ps -aq -f name="${CONTAINER_NAME}" | grep -q .; then
        echo "  删除容器: ${CONTAINER_NAME}"
        docker rm "${CONTAINER_NAME}"
    fi
    
    echo -e "${GREEN}✅ 现有容器已清理${NC}"
    echo ""
}

# 启动新容器
start_container() {
    echo -e "${YELLOW}🚀 启动新容器...${NC}"
    
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --network baidaohui-network \
        -p "${SERVICE_PORT}:${SERVICE_PORT}" \
        -e NODE_ENV=production \
        -e AI_PROXY_PORT="${SERVICE_PORT}" \
        -e OPENROUTER_API_KEY="${OPENROUTER_API_KEY}" \
        -e OPENROUTER_BASE_URL="https://openrouter.ai/api/v1" \
        -e DEFAULT_MODEL="${DEFAULT_AI_MODEL:-deepseek/deepseek-r1-0528:free}" \
        -e FALLBACK_MODELS="${FALLBACK_AI_MODELS:-meta-llama/llama-3.3-8b-instruct:free,google/gemini-2.0-flash-exp:free}" \
        -e RATE_LIMIT_REQUESTS_PER_MINUTE="5" \
        -e MAX_TOKENS_PER_REQUEST="8000" \
        -e MONGODB_URI="${MONGODB_URI}" \
        -e REDIS_URL="redis://redis:6379" \
        -e JWT_SECRET="${JWT_SECRET}" \
        --restart unless-stopped \
        "${DOCKER_IMAGE}"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ 容器启动成功${NC}"
    else
        echo -e "${RED}❌ 容器启动失败${NC}"
        exit 1
    fi
    echo ""
}

# 健康检查
health_check() {
    echo -e "${YELLOW}🏥 执行健康检查...${NC}"
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -n "  尝试 ${attempt}/${max_attempts}: "
        
        if curl -s -f http://localhost:${SERVICE_PORT}/health > /dev/null; then
            echo -e "${GREEN}✅ 服务健康${NC}"
            echo ""
            return 0
        else
            echo -e "${RED}❌ 服务未就绪${NC}"
            sleep 2
            ((attempt++))
        fi
    done
    
    echo -e "${RED}❌ 健康检查失败 - 服务可能未正常启动${NC}"
    echo ""
    echo -e "${YELLOW}📋 容器日志:${NC}"
    docker logs "${CONTAINER_NAME}" --tail 20
    exit 1
}

# 显示服务状态
show_status() {
    echo -e "${BLUE}📊 服务状态:${NC}"
    echo ""
    
    # 显示容器状态
    echo -e "${YELLOW}🐳 Docker容器:${NC}"
    docker ps --filter name="${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # 显示服务信息
    echo -e "${YELLOW}🔗 服务端点:${NC}"
    echo -e "  健康检查: http://localhost:${SERVICE_PORT}/health"
    echo -e "  AI模型列表: http://localhost:${SERVICE_PORT}/models"
    echo -e "  聊天完成: http://localhost:${SERVICE_PORT}/v1/chat/completions"
    echo ""
    
    # 显示nginx状态
    echo -e "${YELLOW}🌐 通过API网关访问:${NC}"
    echo -e "  https://api.baidaohui.com/v1/models"
    echo -e "  https://api.baidaohui.com/v1/chat/completions"
    echo ""
}

# 测试API端点
test_endpoints() {
    echo -e "${YELLOW}🧪 测试API端点...${NC}"
    
    # 测试健康检查
    echo -n "  健康检查: "
    if curl -s -f http://localhost:${SERVICE_PORT}/health | jq -e '.status == "healthy"' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
    else
        echo -e "${RED}❌ 失败${NC}"
    fi
    
    # 测试模型列表
    echo -n "  模型列表: "
    if curl -s -f http://localhost:${SERVICE_PORT}/models -H "Authorization: Bearer test" | jq -e '.object == "list"' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
    else
        echo -e "${YELLOW}⚠️  需要有效API Key${NC}"
    fi
    
    echo ""
}

# 主执行流程
main() {
    echo -e "${GREEN}🤖 AI代理服务部署开始${NC}"
    echo "=================================================="
    echo ""
    
    check_env_vars
    build_image
    stop_existing
    start_container
    health_check
    show_status
    test_endpoints
    
    echo "=================================================="
    echo -e "${GREEN}🎉 AI代理服务部署完成!${NC}"
    echo ""
    echo -e "${BLUE}📝 下一步:${NC}"
    echo -e "  1. 检查nginx配置是否正确代理到端口${SERVICE_PORT}"
    echo -e "  2. 在Master面板中配置API Key"
    echo -e "  3. 测试客户端连接"
    echo ""
}

# 帮助信息
show_help() {
    echo "AI代理服务部署脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -s, --status   仅显示服务状态"
    echo "  -t, --test     仅运行测试"
    echo ""
    echo "环境变量:"
    echo "  OPENROUTER_API_KEY     OpenRouter API密钥 (必需)"
    echo "  MONGODB_URI           MongoDB连接URI (必需)"
    echo "  JWT_SECRET            JWT密钥 (必需)"
    echo "  DEFAULT_AI_MODEL      默认AI模型 (可选)"
    echo "  FALLBACK_AI_MODELS    备用AI模型列表 (可选)"
    echo ""
    echo "示例:"
    echo "  $0                    # 完整部署"
    echo "  $0 -s                 # 查看状态"
    echo "  $0 -t                 # 运行测试"
    echo ""
}

# 处理命令行参数
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -s|--status)
        show_status
        exit 0
        ;;
    -t|--test)
        test_endpoints
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo -e "${RED}错误: 未知选项 '$1'${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac 