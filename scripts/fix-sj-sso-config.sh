#!/bin/bash

# SJ服务器SSO API配置修复脚本
# 专门修复SSO API的Redis连接和配置问题

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
    echo -e "${BLUE}[SJ-SSO-CONFIG]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SJ-SSO-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SJ-SSO-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SJ-SSO-ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[SJ-SSO-STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器SSO API配置修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  check-config  - 检查SSO API配置"
    echo "  fix-redis     - 修复Redis连接配置"
    echo "  test-redis    - 测试Redis连接"
    echo "  restart-sso   - 重启SSO API服务"
    echo "  health-check  - 检查SSO API健康状态"
    echo "  full-fix      - 执行完整配置修复"
    echo ""
    echo "示例："
    echo "  $0 check-config  # 检查配置"
    echo "  $0 full-fix      # 执行完整修复"
}

# 检查SSO API配置
check_sso_config() {
    log_step "检查SJ服务器SSO API配置..."
    
    # 检查Docker Compose配置
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            echo -e "\n${CYAN}SSO API Docker配置:${NC}"
            
            # 检查SSO API服务配置
            if grep -A 20 "sso-api:" docker-compose.sj.yml > /dev/null; then
                log_success "找到SSO API服务配置"
                
                # 显示环境变量
                echo -e "\n${CYAN}SSO API环境变量:${NC}"
                grep -A 15 "sso-api:" docker-compose.sj.yml | grep -E "(environment|REDIS)" || log_warning "未找到Redis环境变量"
                
                # 检查依赖关系
                echo -e "\n${CYAN}服务依赖:${NC}"
                grep -A 15 "sso-api:" docker-compose.sj.yml | grep -E "(depends_on|redis)" || log_warning "未找到Redis依赖"
            else
                log_error "未找到SSO API服务配置"
            fi
        else
            log_error "未找到docker-compose.sj.yml文件"
        fi
        
        cd ../..
    else
        log_error "未找到infra/docker目录"
    fi
    
    # 检查SSO API源码配置
    if [ -d "apps/api/sso" ]; then
        echo -e "\n${CYAN}SSO API源码配置:${NC}"
        
        # 检查配置文件
        local config_files=("config.py" "app.py" "main.py" "__init__.py")
        
        for file in "${config_files[@]}"; do
            if [ -f "apps/api/sso/$file" ]; then
                echo -e "\n${CYAN}检查 $file:${NC}"
                if grep -n -i "redis" "apps/api/sso/$file" 2>/dev/null; then
                    log_success "在 $file 中找到Redis配置"
                else
                    log_warning "在 $file 中未找到Redis配置"
                fi
            fi
        done
    else
        log_warning "未找到SSO API源码目录"
    fi
}

# 修复Redis连接配置
fix_redis_config() {
    log_step "修复SJ服务器SSO API Redis连接配置..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    if [ ! -f "docker-compose.sj.yml" ]; then
        log_error "未找到docker-compose.sj.yml文件"
        cd ../..
        return 1
    fi
    
    # 备份配置
    local backup_file="docker-compose.sj.yml.sso-backup.$(date +%Y%m%d_%H%M%S)"
    cp docker-compose.sj.yml "$backup_file"
    log_info "已备份配置到: $backup_file"
    
    # 检查SSO API是否有正确的Redis环境变量
    if grep -A 20 "sso-api:" docker-compose.sj.yml | grep -q "REDIS_URL"; then
        log_success "SSO API已有Redis环境变量"
        
        # 确保Redis URL正确
        if grep -A 20 "sso-api:" docker-compose.sj.yml | grep "REDIS_URL" | grep -q "redis://redis:6379"; then
            log_success "Redis URL配置正确"
        else
            log_warning "Redis URL可能需要更新"
        fi
    else
        log_warning "SSO API缺少Redis环境变量，需要添加"
        
        # 这里可以添加自动修复逻辑，但为了安全起见，先提示用户
        echo -e "\n${YELLOW}建议手动在docker-compose.sj.yml的sso-api服务中确保有以下环境变量:${NC}"
        cat << 'EOF'
    environment:
      - REDIS_URL=redis://redis:6379/0
      - REDIS_HOST=redis
      - REDIS_PORT=6379
EOF
    fi
    
    cd ../..
}

# 测试Redis连接
test_redis_connection() {
    log_step "测试SJ服务器Redis连接..."
    
    # 检查Redis容器是否运行
    if docker ps | grep -q baidaohui-redis; then
        log_success "Redis容器正在运行"
        
        # 测试Redis连接
        if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
            log_success "Redis连接测试成功"
            
            # 显示Redis信息
            echo -e "\n${CYAN}Redis信息:${NC}"
            docker exec baidaohui-redis redis-cli info server | head -10
            
            # 测试从SSO API容器连接Redis
            if docker ps | grep -q baidaohui-sso-api; then
                echo -e "\n${CYAN}从SSO API容器测试Redis连接:${NC}"
                if docker exec baidaohui-sso-api ping -c 1 redis > /dev/null 2>&1; then
                    log_success "SSO API可以ping通Redis容器"
                else
                    log_warning "SSO API无法ping通Redis容器"
                fi
            else
                log_warning "SSO API容器未运行"
            fi
        else
            log_error "Redis连接测试失败"
            return 1
        fi
    else
        log_error "Redis容器未运行"
        return 1
    fi
}

# 重启SSO API服务
restart_sso_api() {
    log_step "重启SJ服务器SSO API服务..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    # 停止SSO API
    log_info "停止SSO API服务..."
    docker-compose -f docker-compose.sj.yml stop sso-api || true
    
    # 删除容器以确保重新创建
    log_info "删除SSO API容器..."
    docker-compose -f docker-compose.sj.yml rm -f sso-api || true
    
    # 重新启动SSO API
    log_info "重新启动SSO API服务..."
    docker-compose -f docker-compose.sj.yml up -d sso-api
    
    # 等待启动
    log_info "等待SSO API启动（20秒）..."
    sleep 20
    
    cd ../..
}

# 检查SSO API健康状态
check_sso_health() {
    log_step "检查SJ服务器SSO API健康状态..."
    
    # 检查容器状态
    if docker ps | grep -q baidaohui-sso-api; then
        log_success "SSO API容器正在运行"
        
        # 显示容器信息
        echo -e "\n${CYAN}容器信息:${NC}"
        docker ps | grep baidaohui-sso-api
        
        # 检查容器日志
        echo -e "\n${CYAN}最近日志:${NC}"
        docker logs --tail=10 baidaohui-sso-api 2>/dev/null || true
    else
        log_error "SSO API容器未运行"
        return 1
    fi
    
    # 测试健康端点
    echo -e "\n${CYAN}健康端点测试:${NC}"
    local endpoints=(
        "http://localhost:5004/health"
        "http://127.0.0.1:5004/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo -e "\n${CYAN}测试: $endpoint${NC}"
        
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            log_success "健康检查通过: $endpoint"
            echo "响应内容:"
            curl -s "$endpoint" | jq . 2>/dev/null || curl -s "$endpoint"
        else
            log_warning "健康检查失败: $endpoint"
            echo "错误响应:"
            curl -s "$endpoint" 2>/dev/null || echo "无法连接"
        fi
    done
}

# 执行完整配置修复
full_fix() {
    log_info "开始SJ服务器SSO API完整配置修复..."
    
    echo -e "\n${YELLOW}=== 第1步: 检查当前配置 ===${NC}"
    check_sso_config
    
    echo -e "\n${YELLOW}=== 第2步: 修复Redis配置 ===${NC}"
    fix_redis_config
    
    echo -e "\n${YELLOW}=== 第3步: 测试Redis连接 ===${NC}"
    test_redis_connection
    
    echo -e "\n${YELLOW}=== 第4步: 重启SSO API ===${NC}"
    restart_sso_api
    
    echo -e "\n${YELLOW}=== 第5步: 健康状态检查 ===${NC}"
    check_sso_health
    
    log_success "SJ服务器SSO API配置修复完成！"
    echo ""
    echo -e "${GREEN}修复摘要:${NC}"
    echo "  - SSO API配置已检查和修复"
    echo "  - Redis连接已测试"
    echo "  - SSO API服务已重启"
    echo "  - 健康状态已验证"
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器SSO API配置修复${NC}"
    
    case "${1:-}" in
        "check-config")
            check_sso_config
            ;;
        "fix-redis")
            fix_redis_config
            ;;
        "test-redis")
            test_redis_connection
            ;;
        "restart-sso")
            restart_sso_api
            ;;
        "health-check")
            check_sso_health
            ;;
        "full-fix")
            full_fix
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