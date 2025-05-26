#!/bin/bash

echo "=== PrestaShop 502错误诊断 ==="
echo

# 检查PrestaShop容器状态
echo "1. PrestaShop容器状态："
docker ps -a | grep prestashop
echo

# 检查PrestaShop容器日志
echo "2. PrestaShop容器日志（最近50行）："
docker logs --tail 50 baidaohui-prestashop 2>/dev/null || echo "无法获取PrestaShop日志"
echo

# 检查PrestaShop数据库容器状态
echo "3. PrestaShop数据库容器状态："
docker ps -a | grep prestashop-db
echo

# 检查数据库容器日志
echo "4. PrestaShop数据库日志（最近20行）："
docker logs --tail 20 baidaohui-prestashop-db 2>/dev/null || echo "无法获取数据库日志"
echo

# 检查容器内部连接
echo "5. 测试PrestaShop容器内部连接："
docker exec baidaohui-prestashop curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "无法连接到PrestaShop容器内部"
echo

# 检查数据库连接
echo "6. 测试数据库连接："
docker exec baidaohui-prestashop-db mysqladmin ping -h localhost -u prestashop -pprestashop_password 2>/dev/null || echo "数据库连接失败"
echo

# 检查PrestaShop进程
echo "7. PrestaShop容器内进程："
docker exec baidaohui-prestashop ps aux 2>/dev/null || echo "无法查看容器内进程"
echo

# 检查Apache/PHP状态
echo "8. Apache/PHP状态："
docker exec baidaohui-prestashop service apache2 status 2>/dev/null || echo "无法检查Apache状态"
echo

# 检查PHP错误日志
echo "9. PHP错误日志（最近10行）："
docker exec baidaohui-prestashop tail -10 /var/log/apache2/error.log 2>/dev/null || echo "无法读取PHP错误日志"
echo

# 检查PrestaShop安装状态
echo "10. PrestaShop安装状态："
docker exec baidaohui-prestashop ls -la /var/www/html/ 2>/dev/null | head -10 || echo "无法查看PrestaShop文件"
echo

# 检查网络连接
echo "11. 网络连接测试："
echo "从nginx到prestashop的连接："
docker exec baidaohui-nginx curl -s -o /dev/null -w "%{http_code}" http://prestashop 2>/dev/null || echo "nginx无法连接到prestashop"
echo

# 检查资源使用
echo "12. 容器资源使用："
docker stats --no-stream baidaohui-prestashop baidaohui-prestashop-db 2>/dev/null || echo "无法获取资源使用情况"
echo

echo "=== 诊断完成 ==="
echo
echo "常见解决方案："
echo "1. 重启PrestaShop容器: docker restart baidaohui-prestashop"
echo "2. 重启数据库容器: docker restart baidaohui-prestashop-db"
echo "3. 查看完整日志: docker logs baidaohui-prestashop"
echo "4. 进入容器调试: docker exec -it baidaohui-prestashop bash"
echo "5. 重新构建服务: docker-compose -f docker-compose.sj.yml up -d --force-recreate prestashop" 