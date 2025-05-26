#!/bin/bash

# SJ服务器综合问题诊断脚本
# 快速识别和诊断各种常见问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SJ服务器综合问题诊断${NC}"
echo -e "${BLUE}========================${NC}"
echo ""

# 检查Docker环境
echo -e "${PURPLE}[1/7] 检查Docker环境${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装${NC}"
    exit 1
elif ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker未运行${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker环境正常${NC}"
fi

# 检查Docker Compose文件
echo -e "\n${PURPLE}[2/7] 检查Docker Compose配置${NC}"
if [ -f "infra/docker/docker-compose.sj.yml" ]; then
    echo -e "${GREEN}✅ Docker Compose文件存在${NC}"
else
    echo -e "${RED}❌ Docker Compose文件不存在${NC}"
    exit 1
fi

# 检查容器状态
echo -e "\n${PURPLE}[3/7] 检查容器状态${NC}"
cd infra/docker

echo "当前容器状态："
docker-compose -f docker-compose.sj.yml ps

# 统计容器状态
total_containers=$(docker-compose -f docker-compose.sj.yml ps | grep -v "Name" | grep -v "^$" | wc -l)
running_containers=$(docker-compose -f docker-compose.sj.yml ps | grep "Up" | wc -l)
failed_containers=$(docker-compose -f docker-compose.sj.yml ps | grep -E "(Exit|Restarting)" | wc -l)

echo ""
echo "容器统计："
echo -e "总容器数: ${BLUE}$total_containers${NC}"
echo -e "运行中: ${GREEN}$running_containers${NC}"
echo -e "失败/重启: ${RED}$failed_containers${NC}"

# 检查supervisor问题
echo -e "\n${PURPLE}[4/7] 检查Supervisor容器问题${NC}"
if docker ps -a | grep -q "baidaohui-supervisor"; then
    supervisor_status=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "baidaohui-supervisor" | awk '{print $2}')
    
    if [[ "$supervisor_status" == "Exited"* ]]; then
        echo -e "${RED}❌ Supervisor容器已退出${NC}"
        echo "错误日志："
        docker logs baidaohui-supervisor 2>&1 | tail -5
        echo ""
        echo -e "${YELLOW}💡 建议修复：./scripts/quick-fix-sj-supervisor.sh${NC}"
    else
        echo -e "${GREEN}✅ Supervisor容器状态正常${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  未发现Supervisor容器${NC}"
fi

# 检查端口占用
echo -e "\n${PURPLE}[5/7] 检查端口占用情况${NC}"
ports_to_check=(80 5001 5002 5003 5004 5005 6380)
port_conflicts=0

for port in "${ports_to_check[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✅ 端口 $port 已占用${NC}"
    else
        echo -e "${RED}❌ 端口 $port 未占用${NC}"
        ((port_conflicts++))
    fi
done

if [ $port_conflicts -gt 0 ]; then
    echo -e "${YELLOW}💡 建议修复：./scripts/fix-sj-port-conflicts.sh fix${NC}"
fi

# 检查Redis连接
echo -e "\n${PURPLE}[6/7] 检查Redis服务${NC}"
if docker ps | grep -q "baidaohui-redis"; then
    echo -e "${GREEN}✅ Redis容器运行中${NC}"
    
    # 测试Redis连接
    if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis连接正常${NC}"
    else
        echo -e "${RED}❌ Redis连接失败${NC}"
        echo -e "${YELLOW}💡 建议修复：./scripts/fix-sj-redis-port.sh full-fix${NC}"
    fi
else
    echo -e "${RED}❌ Redis容器未运行${NC}"
fi

# 检查关键服务日志
echo -e "\n${PURPLE}[7/7] 检查关键服务错误${NC}"
services_to_check=("sso-api" "auth-api" "profile-api" "chat-api" "shop-api")
error_found=false

for service in "${services_to_check[@]}"; do
    if docker ps | grep -q "baidaohui-$service"; then
        # 检查最近的错误日志
        error_count=$(docker logs baidaohui-$service 2>&1 | tail -20 | grep -i error | wc -l)
        if [ $error_count -gt 0 ]; then
            echo -e "${RED}❌ $service 发现错误日志${NC}"
            docker logs baidaohui-$service 2>&1 | tail -5 | grep -i error
            error_found=true
        else
            echo -e "${GREEN}✅ $service 无明显错误${NC}"
        fi
    else
        echo -e "${RED}❌ $service 容器未运行${NC}"
        error_found=true
    fi
done

cd ../..

# 生成诊断总结
echo -e "\n${BLUE}📋 诊断总结${NC}"
echo -e "${BLUE}============${NC}"

if [ $failed_containers -eq 0 ] && [ $port_conflicts -eq 0 ] && [ "$error_found" = false ]; then
    echo -e "${GREEN}🎉 所有服务运行正常！${NC}"
else
    echo -e "${YELLOW}⚠️  发现以下问题：${NC}"
    
    if [ $failed_containers -gt 0 ]; then
        echo -e "${RED}- $failed_containers 个容器启动失败${NC}"
    fi
    
    if [ $port_conflicts -gt 0 ]; then
        echo -e "${RED}- $port_conflicts 个端口未正常占用${NC}"
    fi
    
    if [ "$error_found" = true ]; then
        echo -e "${RED}- 发现服务错误日志${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔧 推荐修复步骤：${NC}"
    echo "1. 修复supervisor问题: ./scripts/quick-fix-sj-supervisor.sh"
    echo "2. 修复端口冲突: ./scripts/fix-sj-port-conflicts.sh fix"
    echo "3. 修复Redis问题: ./scripts/fix-sj-redis-port.sh full-fix"
    echo "4. 修复SSO配置: ./scripts/fix-sj-sso-config.sh full-fix"
    echo "5. 重新诊断: ./scripts/diagnose-sj-issues.sh"
fi

echo ""
echo -e "${BLUE}📚 更多帮助：${NC}"
echo "- 查看完整修复指南: cat scripts/SJ-REPAIR-README.md"
echo "- 详细supervisor修复: ./scripts/fix-sj-supervisor-error.sh full-fix"
echo "- 完整系统修复: ./scripts/fix-sj-complete.sh fix" 