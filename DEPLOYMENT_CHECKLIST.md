# 部署检查清单

## 📋 部署前检查

### 环境要求

- [ ] Docker 已安装（`docker --version`）
- [ ] Docker Compose 已安装（`docker-compose --version`）
- [ ] 有足够的磁盘空间（至少 5GB）
- [ ] 有足够的内存（至少 4GB）
- [ ] 端口未被占用（18888, 19825, 6080, 5900）

### 文件准备

- [ ] 已克隆或下载项目代码
- [ ] 已设置脚本执行权限（`chmod +x *.sh test/*.sh`）
- [ ] 已创建数据目录（`mkdir -p /data/bb-browser-api/chrome-profile`）

## 🚀 开发环境部署

### 步骤 1：快速启动

```bash
# 运行一键启动脚本
./quick-start.sh
```

### 步骤 2：验证部署

- [ ] 容器正在运行（`docker ps | grep browser-platform`）
- [ ] 所有进程正常（`docker exec browser-platform supervisorctl status`）
- [ ] 端口正常监听（`netstat -tlnp | grep -E '5900|6080|18888'`）
- [ ] 测试通过（`./test/test_services.sh`）

### 步骤 3：访问测试

- [ ] noVNC Web 可访问：http://localhost:6080/vnc.html?token=tec
- [ ] API 可访问：http://localhost:18888/status
- [ ] VNC 可连接：localhost:5900

### 步骤 4：功能测试

- [ ] 可以看到桌面界面
- [ ] 可以打开浏览器
- [ ] API 响应正常
- [ ] 日志无错误

## 🏭 生产环境部署

### 步骤 1：安全配置

- [ ] 修改默认 Token（编辑 `docker-compose.yaml`）
  ```yaml
  environment:
    NOVNC_TOKEN: "your-secure-token-here"
  ```

- [ ] 限制网络访问（如果需要）
  ```yaml
  ports:
    - "127.0.0.1:6080:6080"
  ```

- [ ] 配置防火墙规则
  ```bash
  # 示例：仅允许特定 IP 访问
  sudo ufw allow from 192.168.1.0/24 to any port 6080
  ```

### 步骤 2：部署为系统服务

```bash
# 运行部署脚本
sudo ./deploy-systemd.sh
```

### 步骤 3：验证系统服务

- [ ] 主服务已启用（`sudo systemctl is-enabled bb-browser`）
- [ ] 主服务正在运行（`sudo systemctl is-active bb-browser`）
- [ ] 监控服务正在运行（`sudo systemctl is-active bb-browser-monitor`）
- [ ] 定时器已启用（`sudo systemctl is-enabled bb-browser-healthcheck.timer`）

### 步骤 4：配置监控

- [ ] 监控服务正常运行
  ```bash
  sudo systemctl status bb-browser-monitor
  ```

- [ ] 监控日志正常
  ```bash
  sudo journalctl -u bb-browser-monitor -n 50
  ```

- [ ] 定时健康检查正常
  ```bash
  sudo systemctl list-timers bb-browser-healthcheck.timer
  ```

### 步骤 5：配置日志轮转

- [ ] 日志轮转配置已创建（`/etc/logrotate.d/bb-browser`）
- [ ] 测试日志轮转
  ```bash
  sudo logrotate -d /etc/logrotate.d/bb-browser
  ```

### 步骤 6：配置备份

- [ ] 创建备份脚本
  ```bash
  cat > /root/backup-bb-browser.sh << 'EOF'
  #!/bin/bash
  tar -czf /backup/chrome-profile-$(date +%Y%m%d).tar.gz /data/bb-browser-api/chrome-profile
  find /backup -name "chrome-profile-*.tar.gz" -mtime +7 -delete
  EOF
  chmod +x /root/backup-bb-browser.sh
  ```

- [ ] 配置定时备份
  ```bash
  # 添加到 crontab
  (crontab -l 2>/dev/null; echo "0 2 * * * /root/backup-bb-browser.sh") | crontab -
  ```

### 步骤 7：配置告警（可选）

- [ ] 配置邮件告警
- [ ] 配置 Webhook 通知
- [ ] 集成监控系统（Prometheus、Grafana 等）

## ✅ 部署后验证

### 功能验证

- [ ] 运行完整测试
  ```bash
  ./test/test_services.sh
  ```

- [ ] 访问 noVNC Web 界面
- [ ] 测试 API 接口
- [ ] 测试 VNC 直连

### 稳定性验证

- [ ] 重启容器测试
  ```bash
  docker-compose restart
  sleep 15
  ./test/test_services.sh
  ```

- [ ] 重启服务器测试（生产环境）
  ```bash
  sudo reboot
  # 重启后检查
  sudo systemctl status bb-browser
  ./test/test_services.sh
  ```

- [ ] 进程崩溃恢复测试
  ```bash
  # 杀死 x11vnc 进程
  docker exec browser-platform pkill x11vnc
  # 等待 5 秒
  sleep 5
  # 检查是否自动恢复
  docker exec browser-platform supervisorctl status x11vnc
  ```

### 性能验证

- [ ] 检查资源使用
  ```bash
  docker stats browser-platform --no-stream
  ```

- [ ] 检查响应时间
  ```bash
  time curl http://localhost:18888/status
  ```

- [ ] 检查日志大小
  ```bash
  docker exec browser-platform du -sh /var/log/supervisor/
  ```

## 📊 监控指标

### 关键指标

- [ ] 容器运行时间（Uptime）
- [ ] 进程状态（所有进程 RUNNING）
- [ ] 端口监听状态（5900, 6080, 18888, 19825）
- [ ] VNC 连接成功率
- [ ] API 响应时间
- [ ] 内存使用率（< 80%）
- [ ] CPU 使用率（< 50%）
- [ ] 磁盘使用率（< 80%）

### 监控命令

```bash
# 查看所有指标
echo "=== 容器状态 ==="
docker ps | grep browser-platform

echo "=== 进程状态 ==="
docker exec browser-platform supervisorctl status

echo "=== 资源使用 ==="
docker stats browser-platform --no-stream

echo "=== 端口监听 ==="
docker exec browser-platform netstat -tlnp | grep -E '5900|6080|18888|19825'

echo "=== 日志大小 ==="
docker exec browser-platform du -sh /var/log/supervisor/

echo "=== 最近错误 ==="
docker exec browser-platform bash -c 'tail -20 /var/log/supervisor/*_err.log'
```

## 🔧 故障恢复测试

### 测试场景 1：x11vnc 崩溃

```bash
# 1. 杀死进程
docker exec browser-platform pkill x11vnc

# 2. 等待自动恢复
sleep 5

# 3. 验证恢复
docker exec browser-platform supervisorctl status x11vnc
# 期望：RUNNING

# 4. 测试连接
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'
# 期望：成功
```

### 测试场景 2：容器重启

```bash
# 1. 重启容器
docker-compose restart

# 2. 等待启动
sleep 15

# 3. 运行测试
./test/test_services.sh
# 期望：所有测试通过
```

### 测试场景 3：系统重启（生产环境）

```bash
# 1. 重启系统
sudo reboot

# 2. 重启后检查（SSH 重新连接后）
sudo systemctl status bb-browser
docker exec browser-platform supervisorctl status
./test/test_services.sh
# 期望：服务自动启动，所有测试通过
```

## 📝 文档检查

- [ ] 已阅读 README.md
- [ ] 已阅读 PROJECT_OVERVIEW.md
- [ ] 已阅读 docs/deployment.md
- [ ] 已阅读 docs/troubleshooting.md
- [ ] 已保存 QUICK_REFERENCE.md 以便快速查阅

## 🎓 团队培训

- [ ] 团队成员了解项目架构
- [ ] 团队成员知道如何查看状态
- [ ] 团队成员知道如何重启服务
- [ ] 团队成员知道如何查看日志
- [ ] 团队成员知道如何排查故障
- [ ] 团队成员知道紧急联系方式

## 📞 应急联系

- [ ] 已记录运维负责人联系方式
- [ ] 已记录技术支持联系方式
- [ ] 已记录告警通知渠道
- [ ] 已记录升级流程

## 🎉 部署完成

恭喜！如果所有检查项都已完成，你的 BB Browser API Server 已经成功部署！

### 下一步

1. **定期检查**
   - 每天查看监控日志
   - 每周运行健康检查
   - 每月检查资源使用

2. **定期维护**
   - 每周清理日志
   - 每月更新镜像
   - 每季度备份验证

3. **持续改进**
   - 收集用户反馈
   - 优化配置参数
   - 更新文档

### 快速参考

```bash
# 查看状态
docker exec browser-platform supervisorctl status

# 重启服务
docker exec browser-platform supervisorctl restart x11vnc

# 查看日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 运行测试
./test/test_services.sh

# 查看帮助
cat QUICK_REFERENCE.md
```

---

**记住**：保持这个检查清单，用于未来的部署和故障排查！
