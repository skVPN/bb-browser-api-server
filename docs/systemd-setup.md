# Systemd 服务配置

将 BB Browser API Server 配置为系统服务，实现开机自启和自动监控。

## 1. Docker Compose 服务

### 创建服务文件

```bash
sudo nano /etc/systemd/system/bb-browser.service
```

### 服务配置

```ini
[Unit]
Description=BB Browser API Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### 启用服务

```bash
# 重载 systemd 配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable bb-browser.service

# 启动服务
sudo systemctl start bb-browser.service

# 查看状态
sudo systemctl status bb-browser.service
```

### 管理命令

```bash
# 启动
sudo systemctl start bb-browser

# 停止
sudo systemctl stop bb-browser

# 重启
sudo systemctl restart bb-browser

# 查看日志
sudo journalctl -u bb-browser -f
```

## 2. 监控服务

### 创建监控服务文件

```bash
sudo nano /etc/systemd/system/bb-browser-monitor.service
```

### 监控服务配置

```ini
[Unit]
Description=BB Browser API Server Monitor
After=bb-browser.service
Requires=bb-browser.service

[Service]
Type=simple
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/bin/bash /root/bb-browser-api-server/test/monitor.sh -i 30
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 启用监控服务

```bash
# 重载配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable bb-browser-monitor.service

# 启动监控
sudo systemctl start bb-browser-monitor.service

# 查看状态
sudo systemctl status bb-browser-monitor.service

# 查看监控日志
sudo journalctl -u bb-browser-monitor -f
```

## 3. 定时健康检查

### 创建定时任务

```bash
sudo nano /etc/systemd/system/bb-browser-healthcheck.service
```

### 健康检查服务

```ini
[Unit]
Description=BB Browser API Server Health Check
After=bb-browser.service

[Service]
Type=oneshot
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/bin/bash /root/bb-browser-api-server/test/test_services.sh
StandardOutput=journal
StandardError=journal
```

### 创建定时器

```bash
sudo nano /etc/systemd/system/bb-browser-healthcheck.timer
```

### 定时器配置

```ini
[Unit]
Description=BB Browser API Server Health Check Timer
Requires=bb-browser-healthcheck.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Unit=bb-browser-healthcheck.service

[Install]
WantedBy=timers.target
```

### 启用定时器

```bash
# 重载配置
sudo systemctl daemon-reload

# 启用定时器
sudo systemctl enable bb-browser-healthcheck.timer

# 启动定时器
sudo systemctl start bb-browser-healthcheck.timer

# 查看定时器状态
sudo systemctl list-timers bb-browser-healthcheck.timer

# 手动触发检查
sudo systemctl start bb-browser-healthcheck.service

# 查看检查日志
sudo journalctl -u bb-browser-healthcheck -f
```

## 4. 日志轮转

### 创建日志轮转配置

```bash
sudo nano /etc/logrotate.d/bb-browser
```

### 配置内容

```
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
```

### 测试配置

```bash
sudo logrotate -d /etc/logrotate.d/bb-browser
```

## 5. 完整部署流程

### 一键部署脚本

```bash
#!/bin/bash
# 完整部署脚本

set -e

echo "开始部署 BB Browser API Server..."

# 1. 创建服务文件
cat > /etc/systemd/system/bb-browser.service << 'EOF'
[Unit]
Description=BB Browser API Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# 2. 创建监控服务
cat > /etc/systemd/system/bb-browser-monitor.service << 'EOF'
[Unit]
Description=BB Browser API Server Monitor
After=bb-browser.service
Requires=bb-browser.service

[Service]
Type=simple
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/bin/bash /root/bb-browser-api-server/test/monitor.sh -i 30
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 3. 创建健康检查服务
cat > /etc/systemd/system/bb-browser-healthcheck.service << 'EOF'
[Unit]
Description=BB Browser API Server Health Check
After=bb-browser.service

[Service]
Type=oneshot
WorkingDirectory=/root/bb-browser-api-server
ExecStart=/bin/bash /root/bb-browser-api-server/test/test_services.sh
StandardOutput=journal
StandardError=journal
EOF

# 4. 创建定时器
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

# 5. 创建日志轮转配置
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

# 6. 重载 systemd
systemctl daemon-reload

# 7. 启用所有服务
systemctl enable bb-browser.service
systemctl enable bb-browser-monitor.service
systemctl enable bb-browser-healthcheck.timer

# 8. 启动服务
systemctl start bb-browser.service
sleep 10
systemctl start bb-browser-monitor.service
systemctl start bb-browser-healthcheck.timer

# 9. 显示状态
echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="
echo ""
systemctl status bb-browser.service --no-pager
echo ""
systemctl status bb-browser-monitor.service --no-pager
echo ""
systemctl list-timers bb-browser-healthcheck.timer --no-pager

echo ""
echo "管理命令："
echo "  启动服务: sudo systemctl start bb-browser"
echo "  停止服务: sudo systemctl stop bb-browser"
echo "  查看日志: sudo journalctl -u bb-browser -f"
echo "  查看监控: sudo journalctl -u bb-browser-monitor -f"
```

保存为 `deploy-systemd.sh` 并执行：

```bash
chmod +x deploy-systemd.sh
sudo ./deploy-systemd.sh
```

## 6. 监控和维护

### 查看所有服务状态

```bash
systemctl status bb-browser bb-browser-monitor
```

### 查看实时日志

```bash
# 主服务日志
sudo journalctl -u bb-browser -f

# 监控日志
sudo journalctl -u bb-browser-monitor -f

# 健康检查日志
sudo journalctl -u bb-browser-healthcheck -f

# 所有相关日志
sudo journalctl -u bb-browser* -f
```

### 查看历史日志

```bash
# 最近 100 行
sudo journalctl -u bb-browser -n 100

# 今天的日志
sudo journalctl -u bb-browser --since today

# 最近 1 小时
sudo journalctl -u bb-browser --since "1 hour ago"
```

### 重启服务

```bash
# 重启主服务
sudo systemctl restart bb-browser

# 重启监控
sudo systemctl restart bb-browser-monitor

# 重启所有
sudo systemctl restart bb-browser bb-browser-monitor
```

## 7. 故障排查

### 服务启动失败

```bash
# 查看详细状态
sudo systemctl status bb-browser -l

# 查看启动日志
sudo journalctl -u bb-browser -b

# 检查配置
sudo systemctl cat bb-browser
```

### 监控服务异常

```bash
# 查看监控日志
sudo journalctl -u bb-browser-monitor -n 100

# 手动运行监控脚本
sudo /root/bb-browser-api-server/test/monitor.sh
```

### 定时器不工作

```bash
# 查看定时器列表
sudo systemctl list-timers

# 查看定时器状态
sudo systemctl status bb-browser-healthcheck.timer

# 手动触发
sudo systemctl start bb-browser-healthcheck.service
```

## 8. 卸载

### 停止并禁用服务

```bash
# 停止服务
sudo systemctl stop bb-browser bb-browser-monitor bb-browser-healthcheck.timer

# 禁用服务
sudo systemctl disable bb-browser bb-browser-monitor bb-browser-healthcheck.timer

# 删除服务文件
sudo rm /etc/systemd/system/bb-browser.service
sudo rm /etc/systemd/system/bb-browser-monitor.service
sudo rm /etc/systemd/system/bb-browser-healthcheck.service
sudo rm /etc/systemd/system/bb-browser-healthcheck.timer
sudo rm /etc/logrotate.d/bb-browser

# 重载 systemd
sudo systemctl daemon-reload
```

## 9. 高级配置

### 资源限制

在服务文件中添加：

```ini
[Service]
MemoryLimit=4G
CPUQuota=200%
```

### 失败重启策略

```ini
[Service]
Restart=on-failure
RestartSec=10s
StartLimitInterval=200s
StartLimitBurst=5
```

### 环境变量

```ini
[Service]
Environment="NOVNC_TOKEN=your-token"
Environment="BB_DAEMON_HOST=0.0.0.0"
```

### 依赖关系

```ini
[Unit]
Wants=network-online.target
After=network-online.target docker.service
```

## 10. 监控集成

### Prometheus 监控

可以添加 node_exporter 来监控系统指标：

```bash
# 安装 node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.5.0.linux-amd64.tar.gz
sudo cp node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/

# 创建 systemd 服务
sudo nano /etc/systemd/system/node_exporter.service
```

### Grafana 仪表板

使用 Docker 容器状态和 supervisord 状态创建监控面板。

## 总结

通过 systemd 配置，实现了：

1. ✅ 开机自动启动
2. ✅ 服务崩溃自动重启
3. ✅ 持续健康监控
4. ✅ 定时健康检查
5. ✅ 统一日志管理
6. ✅ 日志自动轮转

这样可以确保服务 24/7 稳定运行，即使出现问题也能自动恢复。
