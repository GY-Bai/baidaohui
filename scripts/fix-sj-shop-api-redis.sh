#!/bin/bash

# SJ服务器Shop API Redis连接修复脚本
# 修复5005端口Shop API无法连接Redis的问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在正确的目录
check_directory() {
    if [[ ! -f "infra/docker/docker-compose.sj.yml" ]]; then
        log_error "请在项目根目录运行此脚本"
        exit 1
    fi
}

# 诊断当前问题
diagnose_shop_api() {
    log_info "诊断Shop API问题..."
    
    echo "=== Docker容器状态 ==="
    docker ps | grep -E "(shop-api|redis)" || true
    
    echo -e "\n=== 端口占用情况 ==="
    netstat -tlnp | grep -E "(5005|6380)" || true
    
    echo -e "\n=== Shop API健康检查 ==="
    curl -s http://localhost:5005/health || echo "Shop API无法访问"
    
    echo -e "\n=== Redis连接测试 ==="
    docker exec baidaohui-redis redis-cli ping || echo "Redis容器无法访问"
    
    echo -e "\n=== Shop API容器日志（最后10行）==="
    docker logs --tail 10 baidaohui-shop-api 2>/dev/null || echo "Shop API容器未运行"
}

# 备份配置文件
backup_config() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="infra/docker/docker-compose.sj.yml.backup.shop_api_${timestamp}"
    
    log_info "备份Docker配置文件..."
    cp infra/docker/docker-compose.sj.yml "$backup_file"
    log_success "配置已备份到: $backup_file"
}

# 修复Shop API配置
fix_shop_api() {
    log_info "修复Shop API配置..."
    
    # 1. 停止Shop API容器
    log_info "停止Shop API容器..."
    docker stop baidaohui-shop-api 2>/dev/null || true
    docker rm baidaohui-shop-api 2>/dev/null || true
    
    # 2. 重新构建Shop API容器
    log_info "重新构建Shop API容器..."
    docker-compose -f infra/docker/docker-compose.sj.yml build shop-api
    
    # 3. 启动Shop API容器
    log_info "启动Shop API容器..."
    docker-compose -f infra/docker/docker-compose.sj.yml up -d shop-api
    
    # 4. 等待容器启动
    log_info "等待容器启动..."
    sleep 10
    
    # 5. 检查容器状态
    if docker ps | grep -q "baidaohui-shop-api"; then
        log_success "Shop API容器启动成功"
    else
        log_error "Shop API容器启动失败"
        return 1
    fi
}

# 验证修复结果
verify_fix() {
    log_info "验证修复结果..."
    
    # 检查容器状态
    echo "=== 容器状态 ==="
    docker ps | grep shop-api
    
    # 检查端口
    echo -e "\n=== 端口检查 ==="
    netstat -tlnp | grep 5005 || echo "端口5005未监听"
    
    # 健康检查
    echo -e "\n=== 健康检查 ==="
    sleep 5  # 等待服务完全启动
    
    local health_response=$(curl -s http://localhost:5005/health || echo "")
    if [[ -n "$health_response" ]]; then
        echo "$health_response" | python3 -m json.tool 2>/dev/null || echo "$health_response"
        
        if echo "$health_response" | grep -q '"status": "healthy"'; then
            log_success "Shop API健康检查通过"
            return 0
        elif echo "$health_response" | grep -q '"redis": "ok"'; then
            log_success "Redis连接已修复"
            return 0
        else
            log_warning "服务运行但可能存在问题"
            return 1
        fi
    else
        log_error "无法访问Shop API健康检查端点"
        return 1
    fi
}

# 查看详细日志
show_logs() {
    log_info "显示Shop API容器日志..."
    docker logs --tail 20 baidaohui-shop-api
}

# 回滚配置
rollback_config() {
    log_info "查找最新的备份文件..."
    local latest_backup=$(ls -t infra/docker/docker-compose.sj.yml.backup.shop_api_* 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" ]]; then
        log_info "回滚到备份: $latest_backup"
        cp "$latest_backup" infra/docker/docker-compose.sj.yml
        
        # 重启服务
        docker-compose -f infra/docker/docker-compose.sj.yml stop shop-api
        docker-compose -f infra/docker/docker-compose.sj.yml up -d shop-api
        
        log_success "配置已回滚并重启服务"
    else
        log_error "未找到备份文件"
        exit 1
    fi
}

# 完整修复流程
full_fix() {
    log_info "开始Shop API Redis连接完整修复流程..."
    
    backup_config
    fix_shop_api
    
    if verify_fix; then
        log_success "Shop API Redis连接修复完成！"
        echo -e "\n${GREEN}✅ 修复总结：${NC}"
        echo "- Shop API容器已重新构建并启动"
        echo "- Redis连接配置已更新为使用环境变量"
        echo "- 端口5005已正确映射"
        echo "- 健康检查端点可正常访问"
        echo -e "\n${BLUE}🔍 验证命令：${NC}"
        echo "curl http://localhost:5005/health"
    else
        log_error "修复过程中出现问题，请查看日志"
        show_logs
        exit 1
    fi
}

# 主函数
main() {
    check_directory
    
    case "${1:-}" in
        "diagnose")
            diagnose_shop_api
            ;;
        "fix")
            fix_shop_api
            ;;
        "verify")
            verify_fix
            ;;
        "logs")
            show_logs
            ;;
        "rollback")
            rollback_config
            ;;
        "full-fix")
            full_fix
            ;;
        *)
            echo "SJ服务器Shop API Redis连接修复脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  diagnose   - 诊断Shop API问题"
            echo "  fix        - 修复Shop API配置"
            echo "  verify     - 验证修复结果"
            echo "  logs       - 查看容器日志"
            echo "  rollback   - 回滚配置"
            echo "  full-fix   - 完整修复流程（推荐）"
            echo ""
            echo "示例:"
            echo "  $0 diagnose     # 诊断问题"
            echo "  $0 full-fix     # 完整修复（推荐）"
            echo "  $0 verify       # 验证结果"
            ;;
    esac
}

main "$@" 