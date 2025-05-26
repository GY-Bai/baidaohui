#!/bin/bash

# SJ服务器SSO API Redis配置修复脚本
# 修复SSO API中硬编码的Redis连接配置问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[SJ-SSO-REDIS-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SJ-SSO-REDIS-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SJ-SSO-REDIS-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SJ-SSO-REDIS-ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[SJ-SSO-REDIS-STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器SSO API Redis配置修复脚本${NC}"
    echo ""
    echo "问题描述："
    echo "  SSO API中Redis连接被硬编码为localhost:6379"
    echo "  但服务器Redis已改为6380端口，导致连接失败"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  check        - 检查当前配置问题"
    echo "  fix          - 修复Redis配置"
    echo "  rebuild      - 重新构建SSO API容器"
    echo "  verify       - 验证修复结果"
    echo "  full-fix     - 执行完整修复流程"
    echo ""
    echo "示例："
    echo "  $0 check         # 检查问题"
    echo "  $0 full-fix      # 完整修复"
}

# 检查当前配置问题
check_config_issue() {
    log_step "检查SJ服务器SSO API Redis配置问题..."
    
    # 检查SSO API源码
    if [ -f "apps/api/sso/supabase_presta.py" ]; then
        log_info "检查SSO API源码中的Redis配置..."
        
        # 检查是否有硬编码的Redis配置
        if grep -n "redis.Redis(host='localhost', port=6379" apps/api/sso/supabase_presta.py > /dev/null 2>&1; then
            log_error "发现硬编码的Redis配置 (localhost:6379)"
            echo "问题行："
            grep -n "redis.Redis(host='localhost', port=6379" apps/api/sso/supabase_presta.py
        elif grep -n "redis.from_url" apps/api/sso/supabase_presta.py > /dev/null 2>&1; then
            log_success "Redis配置已使用环境变量"
        else
            log_warning "未找到Redis配置"
        fi
        
        # 检查是否导入了os模块
        if grep -n "import os" apps/api/sso/supabase_presta.py > /dev/null 2>&1; then
            log_success "已导入os模块"
        else
            log_warning "未导入os模块，可能无法读取环境变量"
        fi
    else
        log_error "未找到SSO API源码文件"
        return 1
    fi
    
    # 检查Docker Compose配置
    if [ -f "infra/docker/docker-compose.sj.yml" ]; then
        log_info "检查Docker Compose中的Redis环境变量..."
        
        if grep -A 10 "sso-api:" infra/docker/docker-compose.sj.yml | grep "REDIS_URL" > /dev/null 2>&1; then
            log_success "Docker Compose中已配置REDIS_URL环境变量"
            grep -A 10 "sso-api:" infra/docker/docker-compose.sj.yml | grep "REDIS_URL"
        else
            log_error "Docker Compose中未找到REDIS_URL环境变量"
        fi
    else
        log_error "未找到Docker Compose配置文件"
        return 1
    fi
    
    # 检查当前Redis端口状态
    log_info "检查Redis端口状态..."
    
    if netstat -tlnp 2>/dev/null | grep ":6379 " > /dev/null; then
        log_warning "端口6379仍被占用"
        netstat -tlnp 2>/dev/null | grep ":6379 "
    else
        log_success "端口6379已释放"
    fi
    
    if netstat -tlnp 2>/dev/null | grep ":6380 " > /dev/null; then
        log_success "端口6380正在使用（Docker Redis）"
        netstat -tlnp 2>/dev/null | grep ":6380 "
    else
        log_error "端口6380未监听"
    fi
}

# 修复Redis配置
fix_redis_config() {
    log_step "修复SJ服务器SSO API Redis配置..."
    
    if [ ! -f "apps/api/sso/supabase_presta.py" ]; then
        log_error "未找到SSO API源码文件"
        return 1
    fi
    
    # 备份原文件
    local backup_file="apps/api/sso/supabase_presta.py.backup.$(date +%Y%m%d_%H%M%S)"
    cp apps/api/sso/supabase_presta.py "$backup_file"
    log_info "已备份原文件到: $backup_file"
    
    # 检查是否已经修复
    if grep -q "redis.from_url" apps/api/sso/supabase_presta.py; then
        log_success "Redis配置已经修复，无需重复操作"
        return 0
    fi
    
    # 创建修复后的配置
    log_info "应用Redis配置修复..."
    
    # 使用sed替换硬编码的Redis配置
    sed -i.tmp '/^redis_client = redis\.Redis(host=.*localhost.*port=6379/c\
# Redis配置 - 支持环境变量\
import os\
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6380/0")  # 默认使用6380端口\
if REDIS_URL.startswith("redis://"):\
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)\
else:\
    # 兼容旧的配置方式\
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")\
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6380"))  # 默认使用6380端口\
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)' apps/api/sso/supabase_presta.py
    
    # 删除临时文件
    rm -f apps/api/sso/supabase_presta.py.tmp
    
    log_success "Redis配置修复完成"
    
    # 验证修复结果
    if grep -q "redis.from_url" apps/api/sso/supabase_presta.py; then
        log_success "验证：Redis配置已正确修复"
    else
        log_error "验证失败：Redis配置修复不成功"
        return 1
    fi
}

# 重新构建SSO API容器
rebuild_sso_container() {
    log_step "重新构建SJ服务器SSO API容器..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到Docker配置目录"
        return 1
    fi
    
    cd infra/docker
    
    # 停止SSO API容器
    log_info "停止SSO API容器..."
    docker-compose -f docker-compose.sj.yml stop sso-api 2>/dev/null || \
    docker compose -f docker-compose.sj.yml stop sso-api 2>/dev/null || true
    
    # 删除容器
    log_info "删除SSO API容器..."
    docker-compose -f docker-compose.sj.yml rm -f sso-api 2>/dev/null || \
    docker compose -f docker-compose.sj.yml rm -f sso-api 2>/dev/null || true
    
    # 删除镜像以强制重新构建
    log_info "删除SSO API镜像..."
    docker rmi docker_sso-api 2>/dev/null || \
    docker rmi infra-docker_sso-api 2>/dev/null || \
    docker rmi baidaohui-sso-api 2>/dev/null || true
    
    # 重新构建并启动
    log_info "重新构建并启动SSO API..."
    docker-compose -f docker-compose.sj.yml up -d --build sso-api 2>/dev/null || \
    docker compose -f docker-compose.sj.yml up -d --build sso-api 2>/dev/null || {
        log_error "Docker Compose命令失败"
        cd ../..
        return 1
    }
    
    cd ../..
    
    # 等待容器启动
    log_info "等待SSO API容器启动（30秒）..."
    sleep 30
}

# 验证修复结果
verify_fix() {
    log_step "验证SJ服务器SSO API修复结果..."
    
    # 检查容器状态
    if docker ps | grep baidaohui-sso-api > /dev/null 2>&1; then
        log_success "SSO API容器正在运行"
        docker ps | grep baidaohui-sso-api
    else
        log_error "SSO API容器未运行"
        return 1
    fi
    
    # 检查容器日志
    log_info "检查容器启动日志..."
    docker logs --tail=20 baidaohui-sso-api 2>/dev/null || true
    
    # 测试健康端点
    log_info "测试SSO API健康端点..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查尝试 $attempt/$max_attempts..."
        
        local health_response=$(curl -s http://localhost:5004/health 2>/dev/null || echo "")
        
        if echo "$health_response" | grep -q '"status":"healthy"'; then
            log_success "🎉 SSO API健康检查通过！"
            echo "响应内容:"
            echo "$health_response" | jq . 2>/dev/null || echo "$health_response"
            return 0
        elif echo "$health_response" | grep -q "Error.*connecting to.*Redis"; then
            log_warning "仍然无法连接Redis (尝试 $attempt/$max_attempts)"
            if [ $attempt -eq $max_attempts ]; then
                log_error "Redis连接问题未解决"
                echo "错误响应: $health_response"
                return 1
            fi
        else
            log_info "等待服务完全启动... (尝试 $attempt/$max_attempts)"
            if [ $attempt -eq $max_attempts ]; then
                log_warning "服务可能未完全启动"
                echo "响应: $health_response"
            fi
        fi
        
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "健康检查超时"
    return 1
}

# 执行完整修复流程
execute_full_fix() {
    log_info "🚀 开始SJ服务器SSO API Redis配置完整修复..."
    
    echo -e "\n${YELLOW}=== 阶段1: 检查配置问题 ===${NC}"
    check_config_issue
    
    echo -e "\n${YELLOW}=== 阶段2: 修复Redis配置 ===${NC}"
    fix_redis_config
    
    echo -e "\n${YELLOW}=== 阶段3: 重新构建容器 ===${NC}"
    rebuild_sso_container
    
    echo -e "\n${YELLOW}=== 阶段4: 验证修复结果 ===${NC}"
    verify_fix
    
    if [ $? -eq 0 ]; then
        log_success "🎉 SJ服务器SSO API Redis配置修复完成！"
        echo ""
        echo -e "${GREEN}修复摘要:${NC}"
        echo "  ✅ SSO API Redis配置已修复"
        echo "  ✅ 容器已重新构建"
        echo "  ✅ 健康检查通过"
        echo ""
        echo -e "${BLUE}现在SSO API可以正确连接到Redis:6380${NC}"
    else
        log_error "修复过程中出现问题，请检查日志"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器SSO API Redis配置修复${NC}"
    
    case "${1:-}" in
        "check")
            check_config_issue
            ;;
        "fix")
            fix_redis_config
            ;;
        "rebuild")
            rebuild_sso_container
            ;;
        "verify")
            verify_fix
            ;;
        "full-fix")
            execute_full_fix
            ;;
        "")
            show_usage
            ;;
        *)
            log_error "未知操作: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 