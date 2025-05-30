#!/bin/bash

# Docker VPS修复脚本
# 专门处理Docker中运行反代的情况

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐋 Docker VPS反代修复${NC}"
echo "=================================="
echo ""

# 检查是否为root用户或sudo权限
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo -e "${RED}❌ 需要sudo权限运行此脚本${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 1. 停止并禁用系统级nginx（避免端口冲突）
echo -e "${YELLOW}1. 处理系统级nginx服务...${NC}"
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "停止系统级nginx服务..."
    sudo systemctl stop nginx
else
    echo "系统级nginx未运行"
fi

if systemctl is-enabled --quiet nginx 2>/dev/null; then
    echo "禁用系统级nginx自启动..."
    sudo systemctl disable nginx
else
    echo "系统级nginx已禁用"
fi

echo -e "${GREEN}✅ 系统级nginx处理完成${NC}"
echo ""

# 2. 检查端口占用情况
echo -e "${YELLOW}2. 检查端口占用状态...${NC}"
echo "检查端口80:"
if sudo netstat -tlnp | grep :80 | head -5; then
    echo ""
else
    echo "端口80未被占用"
fi

echo "检查端口443:"
if sudo netstat -tlnp | grep :443 | head -5; then
    echo ""
else
    echo "端口443未被占用"
fi
echo ""

# 3. 检查和配置防火墙
echo -e "${YELLOW}3. 配置防火墙...${NC}"
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw --force enable
echo -e "${GREEN}✅ 防火墙配置完成${NC}"
echo ""

# 4. 检查Docker服务
echo -e "${YELLOW}4. 检查Docker服务状态...${NC}"
if ! command -v docker &> /dev/null; then
    echo "安装Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "Docker已安装"
fi

if ! command -v docker-compose &> /dev/null; then
    echo "安装Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose已安装"
fi

sudo systemctl start docker
sudo systemctl enable docker
echo -e "${GREEN}✅ Docker服务配置完成${NC}"
echo ""

# 5. 检查项目目录和配置
echo -e "${YELLOW}5. 检查项目配置...${NC}"
if [ ! -f "infra/docker-compose.san-jose.yml" ]; then
    echo -e "${RED}❌ 未找到docker-compose配置文件${NC}"
    echo "请确保在项目根目录运行此脚本"
    exit 1
fi

if [ ! -f "infra/nginx/api.conf" ]; then
    echo -e "${RED}❌ 未找到nginx配置文件${NC}"
    echo "请先运行 git pull 同步最新代码"
    exit 1
fi

echo -e "${GREEN}✅ 项目配置文件检查通过${NC}"
echo ""

# 6. 创建必要目录
echo -e "${YELLOW}6. 创建必要目录...${NC}"
mkdir -p infra/nginx/logs
mkdir -p infra/ssl/certs infra/ssl/private
chmod 755 infra/nginx/logs
echo -e "${GREEN}✅ 目录创建完成${NC}"
echo ""

# 7. 停止现有容器（避免冲突）
echo -e "${YELLOW}7. 清理现有Docker容器...${NC}"
if docker ps -q --filter "name=baidaohui-nginx" | grep -q .; then
    echo "停止现有nginx容器..."
    docker stop baidaohui-nginx || true
    docker rm baidaohui-nginx || true
fi

if docker ps -q --filter "name=nginx" | grep -q .; then
    echo "停止其他nginx容器..."
    docker stop $(docker ps -q --filter "name=nginx") || true
fi

echo -e "${GREEN}✅ 容器清理完成${NC}"
echo ""

# 8. 启动Docker服务
echo -e "${YELLOW}8. 启动Docker反代服务...${NC}"
cd infra || { echo "无法进入infra目录"; exit 1; }

echo "拉取最新镜像..."
docker-compose -f docker-compose.san-jose.yml pull nginx || true

echo "启动nginx反代服务..."
docker-compose -f docker-compose.san-jose.yml up -d nginx

sleep 10

# 检查nginx容器状态
if docker ps | grep -q "baidaohui-nginx"; then
    echo -e "${GREEN}✅ Docker nginx容器启动成功${NC}"
else
    echo -e "${RED}❌ Docker nginx容器启动失败${NC}"
    echo "查看容器日志:"
    docker logs baidaohui-nginx --tail 20 || true
    exit 1
fi

cd ..
echo ""

# 9. 测试连接
echo -e "${YELLOW}9. 测试服务连接...${NC}"
echo -n "测试HTTP端口: "
if curl -s --connect-timeout 10 http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 成功${NC}"
else
    echo -e "${RED}❌ 失败${NC}"
    echo "检查nginx容器日志:"
    docker logs baidaohui-nginx --tail 10 || true
fi

echo -n "测试外部访问: "
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
if curl -s --connect-timeout 10 http://$VPS_IP/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 成功${NC}"
else
    echo -e "${RED}❌ 失败${NC}"
fi
echo ""

# 10. 显示状态总结
echo -e "${BLUE}📋 Docker反代状态总结${NC}"
echo "=================================="
echo ""
echo -e "${GREEN}✅ 已完成的配置:${NC}"
echo "• 停止并禁用系统级nginx"
echo "• 配置防火墙开放端口80/443"
echo "• 启动Docker和Docker Compose"
echo "• 清理冲突的容器"
echo "• 启动Docker nginx反代服务"
echo ""

echo -e "${YELLOW}Docker容器状态:${NC}"
docker ps --filter "name=nginx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
echo ""

echo -e "${YELLOW}端口监听状态:${NC}"
sudo netstat -tlnp | grep -E ":80|:443" || echo "未找到监听端口"
echo ""

echo -e "${YELLOW}测试命令:${NC}"
echo "curl http://localhost/health"
echo "curl http://$VPS_IP/health"
echo ""

echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 启动其他服务: docker-compose -f infra/docker-compose.san-jose.yml up -d"
echo "2. 查看所有容器: docker ps"
echo "3. 查看日志: docker logs baidaohui-nginx"
echo ""
echo -e "${GREEN}🎉 Docker反代修复完成!${NC}" 