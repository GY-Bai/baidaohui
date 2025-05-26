#!/bin/bash

# 修复auth-api和prestashop问题的脚本
# 1. auth-api worker启动失败
# 2. prestashop端口无法访问

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查Docker是否运行
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker未运行，请先启动Docker"
        exit 1
    fi
    log_success "Docker运行正常"
}

# 进入项目目录
cd_to_project() {
    if [ -f "infra/docker/docker-compose.sj.yml" ]; then
        log_success "已在项目根目录"
    else
        log_error "请在项目根目录运行此脚本"
        exit 1
    fi
}

# 停止相关服务
stop_services() {
    log_info "停止auth-api和prestashop服务..."
    
    cd infra/docker
    
    # 停止特定服务
    docker-compose -f docker-compose.sj.yml stop auth-api prestashop || true
    
    log_success "服务已停止"
}

# 重新构建auth-api
rebuild_auth_api() {
    log_info "重新构建auth-api服务..."
    
    cd infra/docker
    
    # 强制重新构建auth-api
    docker-compose -f docker-compose.sj.yml build --no-cache auth-api
    
    log_success "auth-api重新构建完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    cd infra/docker
    
    # 确保依赖服务运行
    docker-compose -f docker-compose.sj.yml up -d redis prestashop-db
    
    # 等待数据库启动
    log_info "等待数据库启动..."
    sleep 10
    
    # 启动prestashop
    docker-compose -f docker-compose.sj.yml up -d prestashop
    
    # 等待prestashop启动
    log_info "等待prestashop启动..."
    sleep 15
    
    # 启动auth-api
    docker-compose -f docker-compose.sj.yml up -d auth-api
    
    log_success "服务启动完成"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    cd infra/docker
    
    # 检查容器状态
    echo "容器状态:"
    docker-compose -f docker-compose.sj.yml ps auth-api prestashop redis prestashop-db
    
    echo ""
    
    # 检查auth-api日志
    log_info "auth-api最新日志:"
    docker-compose -f docker-compose.sj.yml logs --tail 10 auth-api
    
    echo ""
    
    # 检查prestashop日志
    log_info "prestashop最新日志:"
    docker-compose -f docker-compose.sj.yml logs --tail 10 prestashop
    
    echo ""
    
    # 检查端口
    log_info "端口检查:"
    echo "auth-api端口5001:"
    curl -s http://localhost:5001/health || echo "无法连接到auth-api"
    
    echo "prestashop端口8080:"
    curl -s -I http://localhost:8080 | head -1 || echo "无法连接到prestashop"
}

# 验证修复结果
verify_fix() {
    log_info "验证修复结果..."
    
    # 检查auth-api健康状态
    if curl -s http://localhost:5001/health >/dev/null 2>&1; then
        log_success "auth-api服务正常"
    else
        log_error "auth-api服务仍有问题"
    fi
    
    # 检查prestashop
    if curl -s -I http://localhost:8080 >/dev/null 2>&1; then
        log_success "prestashop服务正常"
    else
        log_error "prestashop服务仍有问题"
    fi
    
    # 检查容器是否健康运行
    cd infra/docker
    
    auth_status=$(docker-compose -f docker-compose.sj.yml ps -q auth-api | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
    prestashop_status=$(docker-compose -f docker-compose.sj.yml ps -q prestashop | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
    
    if [ "$auth_status" = "running" ]; then
        log_success "auth-api容器运行正常"
    else
        log_error "auth-api容器状态: $auth_status"
    fi
    
    if [ "$prestashop_status" = "running" ]; then
        log_success "prestashop容器运行正常"
    else
        log_error "prestashop容器状态: $prestashop_status"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}🔧 修复auth-api和prestashop问题${NC}"
    echo "=================================="
    
    check_docker
    cd_to_project
    stop_services
    rebuild_auth_api
    start_services
    
    log_info "等待服务完全启动..."
    sleep 20
    
    check_services
    verify_fix
    
    echo ""
    echo -e "${GREEN}🎉 修复完成！${NC}"
    echo "如果仍有问题，请检查:"
    echo "1. 环境变量配置是否正确"
    echo "2. 数据库连接是否正常"
    echo "3. Redis服务是否运行"
    echo "4. 查看详细日志: docker-compose -f infra/docker/docker-compose.sj.yml logs [服务名]"
}

# 运行主函数
main "$@" 