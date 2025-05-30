#!/bin/bash

# VPS HTTP 521错误修复脚本
# 在VPS上运行，修复nginx和Docker服务问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 VPS HTTP 521错误修复${NC}"
echo "=================================="
echo ""

# 检查是否为root用户或sudo权限
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo -e "${RED}❌ 需要sudo权限运行此脚本${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 1. 检查和修复防火墙
echo -e "${YELLOW}1. 检查和配置防火墙...${NC}"
echo "当前防火墙状态:"
sudo ufw status || echo "防火墙未启用"

echo ""
echo "开放必要端口..."
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

echo "启用防火墙..."
sudo ufw --force enable

echo -e "${GREEN}✅ 防火墙配置完成${NC}"
echo ""

# 2. 检查和安装nginx
echo -e "${YELLOW}2. 检查和配置nginx...${NC}"
if ! command -v nginx &> /dev/null; then
    echo "安装nginx..."
    sudo apt update
    sudo apt install -y nginx
else
    echo "nginx已安装"
fi

# 检查nginx状态
echo "nginx状态:"
sudo systemctl status nginx --no-pager || true

# 启动并启用nginx
echo "启动nginx服务..."
sudo systemctl start nginx
sudo systemctl enable nginx

echo -e "${GREEN}✅ nginx配置完成${NC}"
echo ""

# 3. 检查和安装Docker
echo -e "${YELLOW}3. 检查和配置Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo "安装Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "请重新登录以使Docker组权限生效"
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

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

echo -e "${GREEN}✅ Docker配置完成${NC}"
echo ""

# 4. 检查端口监听
echo -e "${YELLOW}4. 检查端口监听状态...${NC}"
echo "当前监听的端口:"
sudo netstat -tlnp | grep -E ":80|:443|:22" || echo "未找到监听端口"
echo ""

# 5. 测试nginx配置
echo -e "${YELLOW}5. 测试nginx配置...${NC}"
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx配置正确${NC}"
else
    echo -e "${RED}❌ nginx配置有误${NC}"
    echo "查看错误日志:"
    sudo tail -10 /var/log/nginx/error.log || echo "无错误日志"
fi
echo ""

# 6. 重启nginx
echo -e "${YELLOW}6. 重启nginx服务...${NC}"
sudo systemctl restart nginx

if sudo systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx重启成功${NC}"
else
    echo -e "${RED}❌ nginx重启失败${NC}"
    echo "查看状态:"
    sudo systemctl status nginx --no-pager
fi
echo ""

# 7. 创建基本的nginx测试页面
echo -e "${YELLOW}7. 创建测试页面...${NC}"
sudo tee /var/www/html/health > /dev/null <<EOF
{
  "status": "healthy",
  "service": "nginx-test",
  "timestamp": "$(date -Iseconds)",
  "server": "$(hostname)"
}
EOF

# 创建简单的nginx配置用于测试
sudo tee /etc/nginx/sites-available/api-test > /dev/null <<'EOF'
server {
    listen 80;
    server_name api.baidaohui.com;
    
    location /health {
        add_header Content-Type application/json;
        return 200 '{"status":"healthy","service":"nginx-basic","timestamp":"$time_iso8601"}';
    }
    
    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
EOF

# 启用测试配置
sudo ln -sf /etc/nginx/sites-available/api-test /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置并重载
if sudo nginx -t; then
    sudo nginx -s reload
    echo -e "${GREEN}✅ 测试配置已启用${NC}"
else
    echo -e "${RED}❌ 测试配置有误${NC}"
fi
echo ""

# 8. 本地测试
echo -e "${YELLOW}8. 本地连接测试...${NC}"
echo -n "测试HTTP端口: "
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 成功${NC}"
else
    echo -e "${RED}❌ 失败${NC}"
fi

echo -n "测试健康检查端点: "
health_response=$(curl -s http://localhost/health 2>/dev/null || echo "error")
if echo "$health_response" | grep -q "healthy"; then
    echo -e "${GREEN}✅ 成功${NC}"
    echo "响应: $health_response"
else
    echo -e "${RED}❌ 失败${NC}"
    echo "响应: $health_response"
fi
echo ""

# 9. 外部访问测试
echo -e "${YELLOW}9. 外部访问测试...${NC}"
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "VPS外部IP: $VPS_IP"

echo -n "测试外部HTTP访问: "
if curl -s --connect-timeout 10 http://$VPS_IP/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 成功${NC}"
else
    echo -e "${RED}❌ 失败 - 可能被防火墙阻止${NC}"
fi
echo ""

# 10. 总结和下一步
echo -e "${BLUE}📋 修复总结${NC}"
echo "=================================="
echo ""
echo -e "${GREEN}已完成的修复:${NC}"
echo "✅ 防火墙配置 (开放端口80, 443, 22)"
echo "✅ nginx安装和启动"
echo "✅ Docker安装和启动"
echo "✅ 基本nginx测试配置"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 在项目目录运行: git pull (同步最新代码)"
echo "2. 运行部署脚本: ./scripts/deploy_vps.sh"
echo "3. 选择选项10进行nginx和AI代理服务修复"
echo ""
echo -e "${YELLOW}测试命令:${NC}"
echo "# 本地测试"
echo "curl http://localhost/health"
echo ""
echo "# 外部测试"
echo "curl http://$VPS_IP/health"
echo ""
echo -e "${YELLOW}如果问题仍然存在:${NC}"
echo "1. 检查日志: sudo tail -f /var/log/nginx/error.log"
echo "2. 检查防火墙: sudo ufw status verbose"
echo "3. 检查端口: sudo netstat -tlnp | grep :80"
echo "4. 联系VPS提供商检查网络限制"
echo ""
echo -e "${GREEN}🎉 基础修复完成!${NC}" 