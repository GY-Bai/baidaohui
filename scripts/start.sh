#!/bin/bash

# 一键启动脚本 - baidaohui 项目

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Baidaohui 项目一键启动脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装，请先安装 Docker Compose${NC}"
    exit 1
fi

# 检查环境变量文件
if [ ! -f "infra/.env" ]; then
    echo -e "${YELLOW}警告: 环境变量文件 infra/.env 不存在${NC}"
    echo -e "${YELLOW}请复制 infra/.env.example 并配置相应的环境变量${NC}"
    
    if [ -f "infra/.env.example" ]; then
        echo -e "${BLUE}是否要复制示例文件? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            cp infra/.env.example infra/.env
            echo -e "${GREEN}已复制示例文件到 infra/.env${NC}"
            echo -e "${YELLOW}请编辑 infra/.env 文件并配置正确的环境变量${NC}"
            exit 0
        fi
    fi
    exit 1
fi

echo -e "${GREEN}✓ 环境检查通过${NC}"
echo ""

# 选择操作
echo -e "${BLUE}请选择操作:${NC}"
echo "1. 构建并启动所有服务"
echo "2. 仅启动服务（使用现有镜像）"
echo "3. 停止所有服务"
echo "4. 重启所有服务"
echo "5. 查看服务状态"
echo "6. 查看服务日志"
echo "7. 清理所有容器和镜像"
echo ""

read -p "请输入选项 (1-7): " choice

case $choice in
    1)
        echo -e "${YELLOW}开始构建并启动所有服务...${NC}"
        
        # 构建镜像
        echo -e "${BLUE}步骤 1/2: 构建 Docker 镜像${NC}"
        if ./scripts/build_docker.sh; then
            echo -e "${GREEN}✓ 镜像构建成功${NC}"
        else
            echo -e "${RED}✗ 镜像构建失败${NC}"
            exit 1
        fi
        
        # 启动服务
        echo -e "${BLUE}步骤 2/2: 启动服务${NC}"
        cd infra
        if docker-compose up -d; then
            echo -e "${GREEN}✓ 服务启动成功${NC}"
        else
            echo -e "${RED}✗ 服务启动失败${NC}"
            exit 1
        fi
        ;;
    2)
        echo -e "${YELLOW}启动服务...${NC}"
        cd infra
        docker-compose up -d
        ;;
    3)
        echo -e "${YELLOW}停止所有服务...${NC}"
        cd infra
        docker-compose down
        echo -e "${GREEN}✓ 服务已停止${NC}"
        ;;
    4)
        echo -e "${YELLOW}重启所有服务...${NC}"
        cd infra
        docker-compose restart
        echo -e "${GREEN}✓ 服务已重启${NC}"
        ;;
    5)
        echo -e "${BLUE}服务状态:${NC}"
        cd infra
        docker-compose ps
        ;;
    6)
        echo -e "${BLUE}选择要查看日志的服务:${NC}"
        echo "1. 所有服务"
        echo "2. 认证服务 (auth-service)"
        echo "3. 聊天服务 (chat-service)"
        echo "4. 算命服务 (fortune-service)"
        echo "5. 电商API服务 (ecommerce-api-service)"
        echo "6. 支付服务 (payment-service)"
        echo "7. 邀请链接服务 (invite-service)"
        echo "8. 密钥管理服务 (key-service)"
        
        read -p "请输入选项 (1-8): " log_choice
        
        cd infra
        case $log_choice in
            1) docker-compose logs -f ;;
            2) docker-compose logs -f auth-service ;;
            3) docker-compose logs -f chat-service ;;
            4) docker-compose logs -f fortune-service ;;
            5) docker-compose logs -f ecommerce-api-service ;;
            6) docker-compose logs -f payment-service ;;
            7) docker-compose logs -f invite-service ;;
            8) docker-compose logs -f key-service ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
        ;;
    7)
        echo -e "${RED}警告: 这将删除所有容器和镜像!${NC}"
        read -p "确定要继续吗? (y/N): " confirm
        if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "${YELLOW}清理容器和镜像...${NC}"
            cd infra
            docker-compose down -v --rmi all
            echo -e "${GREEN}✓ 清理完成${NC}"
        else
            echo -e "${BLUE}操作已取消${NC}"
        fi
        ;;
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac

# 显示服务访问信息
if [[ $choice == 1 || $choice == 2 ]]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    服务启动完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}服务访问地址:${NC}"
    echo "• 认证服务:     http://localhost:5001"
    echo "• 聊天服务:     http://localhost:5002"
    echo "• 算命服务:     http://localhost:5003"
    echo "• 电商API服务:  http://localhost:5005"
    echo "• 支付服务:     http://localhost:5006"
    echo "• 邀请链接服务: http://localhost:5007"
    echo "• 密钥管理服务: http://localhost:5008"
    echo ""
    echo -e "${BLUE}健康检查:${NC}"
    echo "curl http://localhost:5001/health"
    echo ""
    echo -e "${BLUE}查看日志:${NC}"
    echo "./scripts/start.sh (选择选项 6)"
    echo ""
    echo -e "${YELLOW}注意: 请确保已正确配置 infra/.env 文件中的环境变量${NC}"
fi 