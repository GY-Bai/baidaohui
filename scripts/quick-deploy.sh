#!/bin/bash

# 快速修复和部署脚本
# 修复HTTP 521错误并部署AI代理服务

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 百刀会系统快速修复和部署${NC}"
echo "============================================"
echo ""

# 检查环境变量
check_env() {
    echo -e "${YELLOW}📋 检查必需的环境变量...${NC}"
    
    if [ ! -f ".env" ]; then
        echo -e "${RED}❌ .env 文件不存在${NC}"
        echo "请复制 infra/env.example 到 .env 并配置必要的环境变量"
        exit 1
    fi
    
    source .env
    
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo -e "${RED}❌ OPENROUTER_API_KEY 未设置${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 环境变量检查通过${NC}"
    echo ""
}

# 停止现有服务
stop_services() {
    echo -e "${YELLOW}🛑 停止现有服务...${NC}"
    
    # 停止圣何塞VPS服务
    if docker-compose -f infra/docker-compose.san-jose.yml ps -q 2>/dev/null | grep -q .; then
        docker-compose -f infra/docker-compose.san-jose.yml down
        echo "  已停止圣何塞VPS服务"
    fi
    
    # 清理旧容器和镜像
    docker system prune -f >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ 服务停止完成${NC}"
    echo ""
}

# 构建AI代理服务镜像
build_ai_proxy() {
    echo -e "${YELLOW}🔨 构建AI代理服务镜像...${NC}"
    
    if [ ! -d "services/ai-proxy-service" ]; then
        echo -e "${RED}❌ AI代理服务目录不存在${NC}"
        exit 1
    fi
    
    cd services/ai-proxy-service
    
    if docker build -t baidaohui/ai-proxy-service:latest .; then
        echo -e "${GREEN}✅ AI代理服务镜像构建成功${NC}"
    else
        echo -e "${RED}❌ AI代理服务镜像构建失败${NC}"
        exit 1
    fi
    
    cd ../../
    echo ""
}

# 启动所有服务
start_services() {
    echo -e "${YELLOW}🚀 启动所有服务...${NC}"
    
    # 启动圣何塞VPS服务（包括AI代理服务）
    docker-compose -f infra/docker-compose.san-jose.yml up -d
    
    echo -e "${GREEN}✅ 服务启动完成${NC}"
    echo ""
}

# 等待服务就绪
wait_for_services() {
    echo -e "${YELLOW}⏳ 等待服务就绪...${NC}"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -n "  检查第 ${attempt}/${max_attempts} 次: "
        
        # 检查AI代理服务
        if curl -s -f http://localhost:5012/health >/dev/null 2>&1; then
            echo -e "${GREEN}✅ AI代理服务就绪${NC}"
            break
        else
            echo -e "${YELLOW}⏳ 等待中...${NC}"
            sleep 3
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo -e "${RED}❌ 服务启动超时${NC}"
        echo ""
        echo -e "${YELLOW}📋 容器状态:${NC}"
        docker ps
        echo ""
        echo -e "${YELLOW}📋 AI代理服务日志:${NC}"
        docker logs ai-proxy-service --tail 20
        exit 1
    fi
    
    echo ""
}

# 验证部署
verify_deployment() {
    echo -e "${YELLOW}✅ 验证部署...${NC}"
    
    # 检查Docker容器状态
    echo "Docker容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(nginx|ai-proxy-service|auth-service|redis)"
    echo ""
    
    # 测试健康检查端点
    echo "健康检查测试:"
    
    # AI代理服务本地健康检查
    if curl -s -f http://localhost:5012/health >/dev/null; then
        echo -e "  AI代理服务 (本地): ${GREEN}✅ 正常${NC}"
    else
        echo -e "  AI代理服务 (本地): ${RED}❌ 异常${NC}"
    fi
    
    # 测试API Key认证
    if curl -s -f -H "Authorization: Bearer wjz5788@gmail.com" http://localhost:5012/v1/models >/dev/null; then
        echo -e "  API Key认证: ${GREEN}✅ 正常${NC}"
    else
        echo -e "  API Key认证: ${RED}❌ 异常${NC}"
    fi
    
    echo ""
}

# 显示访问信息
show_access_info() {
    echo -e "${BLUE}🌐 访问信息${NC}"
    echo "============================================"
    echo ""
    echo -e "${YELLOW}AI代理服务:${NC}"
    echo "  本地端点: http://localhost:5012"
    echo "  健康检查: http://localhost:5012/health"
    echo "  模型列表: http://localhost:5012/v1/models"
    echo "  聊天完成: http://localhost:5012/v1/chat/completions"
    echo ""
    echo -e "${YELLOW}API网关（nginx代理后）:${NC}"
    echo "  健康检查: https://api.baidaohui.com/v1/health"
    echo "  模型列表: https://api.baidaohui.com/v1/models"
    echo "  聊天完成: https://api.baidaohui.com/v1/chat/completions"
    echo ""
    echo -e "${YELLOW}认证信息:${NC}"
    echo "  API Key: wjz5788@gmail.com"
    echo "  使用方法: Authorization: Bearer wjz5788@gmail.com"
    echo ""
    echo -e "${YELLOW}健康检查面板:${NC}"
    echo "  前端页面: https://www.baidaohui.com/health"
    echo ""
}

# 主执行流程
main() {
    check_env
    stop_services
    build_ai_proxy
    start_services
    wait_for_services
    verify_deployment
    show_access_info
    
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo ""
    echo -e "${YELLOW}💡 下一步:${NC}"
    echo "  1. 访问健康检查页面验证所有服务状态"
    echo "  2. 运行测试脚本: ./scripts/test-ai-proxy.sh"
    echo "  3. 检查nginx配置和SSL证书"
    echo ""
}

# 错误处理
trap 'echo -e "\n${RED}❌ 部署过程中发生错误${NC}"; exit 1' ERR

# 执行主函数
main "$@" 