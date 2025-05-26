#!/bin/bash

# 诊断auth-api和prestashop问题的脚本

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
        log_error "Docker未运行"
        return 1
    fi
    log_success "Docker运行正常"
}

# 检查容器状态
check_containers() {
    log_info "检查容器状态..."
    
    cd infra/docker
    
    echo "相关容器状态:"
    docker-compose -f docker-compose.sj.yml ps auth-api prestashop redis prestashop-db 2>/dev/null || {
        log_error "无法获取容器状态，可能docker-compose文件有问题"
        return 1
    }
    
    echo ""
}

# 检查auth-api问题
check_auth_api() {
    log_info "检查auth-api问题..."
    
    cd infra/docker
    
    # 检查容器是否存在
    if ! docker-compose -f docker-compose.sj.yml ps -q auth-api >/dev/null 2>&1; then
        log_error "auth-api容器不存在"
        return 1
    fi
    
    # 检查容器状态
    local status=$(docker-compose -f docker-compose.sj.yml ps auth-api | grep auth-api | awk '{print $4}' || echo "unknown")
    echo "auth-api状态: $status"
    
    # 检查最近日志
    echo ""
    log_info "auth-api最近日志:"
    docker-compose -f docker-compose.sj.yml logs --tail 20 auth-api 2>/dev/null || {
        log_error "无法获取auth-api日志"
    }
    
    echo ""
    
    # 检查端口
    log_info "检查auth-api端口5001:"
    if curl -s http://localhost:5001/health >/dev/null 2>&1; then
        log_success "auth-api端口5001可访问"
    else
        log_error "auth-api端口5001无法访问"
    fi
    
    echo ""
}

# 检查prestashop问题
check_prestashop() {
    log_info "检查prestashop问题..."
    
    cd infra/docker
    
    # 检查容器是否存在
    if ! docker-compose -f docker-compose.sj.yml ps -q prestashop >/dev/null 2>&1; then
        log_error "prestashop容器不存在"
        return 1
    fi
    
    # 检查容器状态
    local status=$(docker-compose -f docker-compose.sj.yml ps prestashop | grep prestashop | awk '{print $4}' || echo "unknown")
    echo "prestashop状态: $status"
    
    # 检查端口配置
    echo ""
    log_info "检查prestashop端口配置:"
    docker-compose -f docker-compose.sj.yml config | grep -A 5 -B 5 "prestashop:" | grep -A 10 "ports:" || {
        log_warning "未找到prestashop端口配置"
    }
    
    # 检查最近日志
    echo ""
    log_info "prestashop最近日志:"
    docker-compose -f docker-compose.sj.yml logs --tail 20 prestashop 2>/dev/null || {
        log_error "无法获取prestashop日志"
    }
    
    echo ""
    
    # 检查端口
    log_info "检查prestashop端口8080:"
    if curl -s -I http://localhost:8080 >/dev/null 2>&1; then
        log_success "prestashop端口8080可访问"
    else
        log_error "prestashop端口8080无法访问"
    fi
    
    echo ""
}

# 检查依赖服务
check_dependencies() {
    log_info "检查依赖服务..."
    
    cd infra/docker
    
    # 检查Redis
    log_info "检查Redis:"
    if docker-compose -f docker-compose.sj.yml ps redis | grep -q "Up"; then
        log_success "Redis运行正常"
    else
        log_error "Redis未运行"
    fi
    
    # 检查数据库
    log_info "检查prestashop数据库:"
    if docker-compose -f docker-compose.sj.yml ps prestashop-db | grep -q "Up"; then
        log_success "prestashop数据库运行正常"
    else
        log_error "prestashop数据库未运行"
    fi
    
    echo ""
}

# 检查配置文件
check_config() {
    log_info "检查配置文件..."
    
    # 检查docker-compose文件
    if [ -f "infra/docker/docker-compose.sj.yml" ]; then
        log_success "docker-compose.sj.yml存在"
    else
        log_error "docker-compose.sj.yml不存在"
        return 1
    fi
    
    # 检查auth-api requirements
    if [ -f "apps/api/auth/requirements.txt" ]; then
        log_info "auth-api依赖:"
        cat apps/api/auth/requirements.txt
        
        # 检查是否包含redis
        if grep -q "redis" apps/api/auth/requirements.txt; then
            log_success "auth-api包含redis依赖"
        else
            log_error "auth-api缺少redis依赖"
        fi
    else
        log_error "auth-api requirements.txt不存在"
    fi
    
    echo ""
}

# 提供修复建议
provide_suggestions() {
    log_info "修复建议..."
    
    echo "基于诊断结果，建议执行以下修复步骤:"
    echo ""
    echo "1. 如果auth-api worker启动失败:"
    echo "   - 运行: ./scripts/fix-auth-api-prestashop.sh"
    echo "   - 这将重新构建auth-api并修复依赖问题"
    echo ""
    echo "2. 如果prestashop端口无法访问:"
    echo "   - 运行: ./scripts/fix-auth-api-prestashop.sh"
    echo "   - 这将修复prestashop的端口配置"
    echo ""
    echo "3. 如果依赖服务有问题:"
    echo "   - 先启动依赖服务: cd infra/docker && docker-compose -f docker-compose.sj.yml up -d redis prestashop-db"
    echo "   - 然后运行修复脚本"
    echo ""
    echo "4. 查看详细日志:"
    echo "   - auth-api: docker-compose -f infra/docker/docker-compose.sj.yml logs auth-api"
    echo "   - prestashop: docker-compose -f infra/docker/docker-compose.sj.yml logs prestashop"
    echo ""
}

# 主函数
main() {
    echo -e "${BLUE}🔍 诊断auth-api和prestashop问题${NC}"
    echo "=================================="
    
    # 进入项目目录
    if [ -f "infra/docker/docker-compose.sj.yml" ]; then
        log_success "已在项目根目录"
    else
        log_error "请在项目根目录运行此脚本"
        exit 1
    fi
    
    check_docker
    check_config
    check_dependencies
    check_containers
    check_auth_api
    check_prestashop
    provide_suggestions
    
    echo ""
    echo -e "${GREEN}🎯 诊断完成！${NC}"
    echo "请根据上述建议进行修复。"
}

# 运行主函数
main "$@" 