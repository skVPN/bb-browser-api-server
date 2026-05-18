#!/bin/bash
# 设置所有脚本的执行权限

echo "设置脚本执行权限..."

chmod +x start.sh
chmod +x quick-start.sh
chmod +x deploy-systemd.sh
chmod +x test/test_services.sh
chmod +x test/monitor.sh

echo "完成！"
echo ""
echo "可执行的脚本："
echo "  ./start.sh              - 手动启动脚本（调试用）"
echo "  ./quick-start.sh        - 一键启动脚本"
echo "  ./deploy-systemd.sh     - Systemd 服务部署"
echo "  ./test/test_services.sh - 服务健康检查"
echo "  ./test/monitor.sh       - 持续监控脚本"
