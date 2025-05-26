#!/bin/bash

# SJ服务器修复脚本列表
# 显示所有可用的修复脚本和使用说明

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛠️  SJ服务器修复脚本工具集${NC}"
echo -e "${BLUE}===========================${NC}"
echo ""

echo -e "${CYAN}📋 快速诊断和修复${NC}"
echo -e "${GREEN}./scripts/diagnose-sj-issues.sh${NC}                    - 综合问题诊断（推荐首先运行）"
echo -e "${GREEN}./scripts/quick-fix-sj-supervisor.sh${NC}               - Supervisor问题一键修复"
echo ""

echo -e "${CYAN}🔧 专项修复脚本${NC}"
echo -e "${YELLOW}./scripts/fix-auth-api-prestashop.sh${NC}               - Auth API和PrestaShop修复"
echo "  修复: auth-api worker启动失败, prestashop端口无法访问"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-supervisor-error.sh [操作]${NC}        - Supervisor容器修复"
echo "  操作: diagnose, full-fix, disable, use-image, fix-config, verify"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-port-conflicts.sh [操作]${NC}          - 端口冲突修复"
echo "  操作: diagnose, fix, fix-80, fix-mapping, verify, rollback"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-complete.sh [操作]${NC}                - 完整修复流程"
echo "  操作: diagnose, fix, verify, rollback"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-redis-port.sh [操作]${NC}              - Redis端口修复"
echo "  操作: check, stop-external, fix-port, restart, verify, full-fix"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-sso-config.sh [操作]${NC}              - SSO API配置修复"
echo "  操作: check-config, fix-redis, test-redis, restart-sso, health-check, full-fix"
echo ""
echo -e "${YELLOW}./scripts/fix-sj-sso-redis-config.sh [操作]${NC}        - SSO API Redis配置修复"
echo "  操作: check, fix, rebuild, verify, full-fix"
echo ""

echo -e "${CYAN}📚 文档和帮助${NC}"
echo -e "${PURPLE}cat scripts/SJ-REPAIR-README.md${NC}                    - 完整修复指南"
echo -e "${PURPLE}./scripts/list-sj-scripts.sh${NC}                       - 显示此脚本列表"
echo ""

echo -e "${CYAN}🚀 推荐修复流程${NC}"
echo -e "${BLUE}1.${NC} 诊断问题:     ${GREEN}./scripts/diagnose-sj-issues.sh${NC}"
echo -e "${BLUE}2.${NC} 修复supervisor: ${GREEN}./scripts/quick-fix-sj-supervisor.sh${NC}"
echo -e "${BLUE}3.${NC} 修复端口冲突:   ${GREEN}./scripts/fix-sj-port-conflicts.sh fix${NC}"
echo -e "${BLUE}4.${NC} 修复Redis:     ${GREEN}./scripts/fix-sj-redis-port.sh full-fix${NC}"
echo -e "${BLUE}5.${NC} 验证结果:      ${GREEN}./scripts/diagnose-sj-issues.sh${NC}"
echo ""

echo -e "${CYAN}⚡ 常见问题快速修复${NC}"
echo -e "${RED}问题: auth-api worker启动失败${NC}"
echo -e "修复: ${GREEN}./scripts/fix-auth-api-prestashop.sh${NC}"
echo ""
echo -e "${RED}问题: prestashop端口无法访问${NC}"
echo -e "修复: ${GREEN}./scripts/fix-auth-api-prestashop.sh${NC}"
echo ""
echo -e "${RED}问题: supervisor容器启动失败${NC}"
echo -e "修复: ${GREEN}./scripts/quick-fix-sj-supervisor.sh${NC}"
echo ""
echo -e "${RED}问题: 端口80冲突${NC}"
echo -e "修复: ${GREEN}./scripts/fix-sj-port-conflicts.sh fix-80${NC}"
echo ""
echo -e "${RED}问题: Redis连接失败${NC}"
echo -e "修复: ${GREEN}./scripts/fix-sj-redis-port.sh full-fix${NC}"
echo ""
echo -e "${RED}问题: SSO API Redis错误${NC}"
echo -e "修复: ${GREEN}./scripts/fix-sj-sso-redis-config.sh full-fix${NC}"
echo ""

echo -e "${CYAN}📞 获取帮助${NC}"
echo "如果遇到问题，请："
echo "1. 运行诊断脚本获取详细信息"
echo "2. 查看完整修复指南: cat scripts/SJ-REPAIR-README.md"
echo "3. 检查容器日志: docker logs [容器名]"
echo "4. 提供错误信息和系统环境" 