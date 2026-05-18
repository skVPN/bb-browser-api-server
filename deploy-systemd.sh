#!/bin/bash
# Systemd 服务部署脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "BB Browser API Server Systemd 部署"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 root 权限运行此脚本${NC}"
    echo "使用: sudo $0"
    exit 1
fi

# 获取当前目录
WORK_DIR=$(pwd)
echo "工作目录: $WORK_DIR"
echo ""

# 1. 创建主服务文件
echo -n "创建 bb-browser.service... "
cat > /etc/systemd/system/bb-browser.service << EOF
[Unit]
Description=BB Browser API Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}✓${NC}"

# 2. 创建监控服务
echo -n "创建 bb-browser-monitor.service... "
cat > /etc/systemd/system/bb-browser-monitor.service << EOF
[Unit]
Description=BB Browser API Server Monitor
After=bb-browser.service
Requires=bb-browser.service

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
ExecStart=/bin/bash $WORK_DIR/test/monitor.sh -i 30
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}✓${NC}"

# 3. 创建健康检查服务
echo -n "创建 bb-browser-healthcheck.service... "
cat > /etc/systemd/system/bb-browser-healthcheck.service << EOF
[Unit]
Description=BB Browser API Server Health Check
After=bb-browser.service

[Service]
Type=oneshot
WorkingDirectory=$WORK_DIR
ExecStart=/bin/bash $WORK_DIR/test/test_services.sh
StandardOutput=journal
StandardError=journal
EOF
echo -e "${GREEN}✓${NC}"

# 4. 创建定时器
echo -n "创建 bb-browser-healthcheck.timer... "
cat > /etc/systemd/system/bb-browser-healthcheck.timer << 'EOF'
[Unit]
Description=BB Browser API Server Health Check Timer
Requires=bb-browser-healthcheck.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Unit=bb-browser-healthcheck.service

[Install]
WantedBy=timers.target
EOF
echo -e "${GREEN}✓${NC}"

# 5. 创建日志轮转配置
echo -n "创建日志轮转配置... "
cat > /etc/logrotate.d/bb-browser << 'EOF'
/var/log/bb-browser-monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

/var/log/bb-browser-alerts.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
echo -e "${GREEN}✓${NC}"

# 6. 设置脚本执行权限
echo -n "设置脚本执行权限... "
chmod +x "$WORK_DIR/test/monitor.sh"
chmod +x "$WORK_DIR/test/test_services.sh"
chmod +x "$WORK_DIR/quick-start.sh"
echo -e "${GREEN}✓${NC}"

# 7. 重载 systemd
echo -n "重载 systemd 配置... "
systemctl daemon-reload
echo -e "${GREEN}✓${NC}"

# 8. 启用服务
echo "启用服务..."
systemctl enable bb-browser.service
systemctl enable bb-browser-monitor.service
systemctl enable bb-browser-healthcheck.timer
echo -e "${GREEN}✓ 所有服务已启用${NC}"

# 9. 询问是否立即启动
echo ""
read -p "是否立即启动服务? (Y/n): " start_now
if [[ ! $start_now =~ ^[Nn]$ ]]; then
    echo ""
    echo "启动服务..."
    
    # 启动主服务
    echo -n "启动 bb-browser... "
    systemctl start bb-browser.service
    echo -e "${GREEN}✓${NC}"
    
    # 等待容器启动
    echo -n "等待容器启动"
    for i in {1..10}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    # 启动监控
    echo -n "启动监控服务... "
    systemctl start bb-browser-monitor.service
    echo -e "${GREEN}✓${NC}"
    
    # 启动定时器
    echo -n "启动健康检查定时器... "
    systemctl start bb-browser-healthcheck.timer
    echo -e "${GREEN}✓${NC}"
fi

# 10. 显示状态
echo ""
echo "=========================================="
echo -e "${GREEN}部署完成！${NC}"
echo "=========================================="
echo ""

echo "服务状态："
systemctl status bb-browser.service --no-pager -l || true
echo ""
systemctl status bb-browser-monitor.service --no-pager -l || true
echo ""

echo "定时器状态："
systemctl list-timers bb-browser-healthcheck.timer --no-pager || true
echo ""

echo "=========================================="
echo "管理命令："
echo "=========================================="
echo ""
echo "启动服务:"
echo "  sudo systemctl start bb-browser"
echo ""
echo "停止服务:"
echo "  sudo systemctl stop bb-browser"
echo ""
echo "重启服务:"
echo "  sudo systemctl restart bb-browser"
echo ""
echo "查看状态:"
echo "  sudo systemctl status bb-browser"
echo "  sudo systemctl status bb-browser-monitor"
echo ""
echo "查看日志:"
echo "  sudo journalctl -u bb-browser -f"
echo "  sudo journalctl -u bb-browser-monitor -f"
echo "  sudo journalctl -u bb-browser-healthcheck -f"
echo ""
echo "手动健康检查:"
echo "  sudo systemctl start bb-browser-healthcheck.service"
echo ""
echo "访问服务:"
echo "  noVNC: http://localhost:6080/vnc.html?token=tec"
echo "  API:   http://localhost:18888"
echo ""
