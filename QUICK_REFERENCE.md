# 快速参考

## 🚀 快速启动

```bash
# 方式 1: 一键启动（推荐新手）
./quick-start.sh

# 方式 2: Docker Compose（推荐开发）
docker-compose up -d

# 方式 3: Systemd 服务（推荐生产）
sudo ./deploy-systemd.sh
```

## 🌐 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| noVNC Web | http://localhost:6080/vnc.html?token=tec | Web 界面 |
| VNC 直连 | localhost:5900 | VNC 客户端 |
| API 接口 | http://localhost:18888 | HTTP API |
| CDP 端口 | localhost:19825 | Chrome DevTools |

## 📊 查看状态

```bash
# 查看所有进程状态
docker exec browser-platform supervisorctl status

# 查看容器日志
docker-compose logs -f

# 运行完整测试
./test/test_services.sh

# 查看单个服务日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log
```

## 🔧 常用命令

### 进程管理

```bash
# 重启单个服务
docker exec browser-platform supervisorctl restart x11vnc
docker exec browser-platform supervisorctl restart websockify

# 重启所有服务
docker exec browser-platform supervisorctl restart all

# 停止服务
docker exec browser-platform supervisorctl stop x11vnc

# 启动服务
docker exec browser-platform supervisorctl start x11vnc
```

### 容器管理

```bash
# 启动容器
docker-compose up -d

# 停止容器
docker-compose down

# 重启容器
docker-compose restart

# 查看日志
docker-compose logs -f

# 进入容器
docker exec -it browser-platform bash
```

### Systemd 管理（如果已部署）

```bash
# 启动服务
sudo systemctl start bb-browser

# 停止服务
sudo systemctl stop bb-browser

# 重启服务
sudo systemctl restart bb-browser

# 查看状态
sudo systemctl status bb-browser

# 查看日志
sudo journalctl -u bb-browser -f

# 查看监控日志
sudo journalctl -u bb-browser-monitor -f
```

## 🐛 故障排查

### 问题：VNC 连接被拒绝

```bash
# 快速修复（按顺序尝试）
# 1. 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc

# 2. 重启 websockify
docker exec browser-platform supervisorctl restart websockify

# 3. 重启服务链
docker exec browser-platform supervisorctl restart xvfb
sleep 2
docker exec browser-platform supervisorctl restart x11vnc
sleep 2
docker exec browser-platform supervisorctl restart websockify

# 4. 重启所有服务
docker exec browser-platform supervisorctl restart all

# 5. 重启容器
docker-compose restart
```

### 问题：中文显示乱码

```bash
# 快速修复
chmod +x fix-chinese-fonts.sh
./fix-chinese-fonts.sh

# 或手动修复
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 验证字体
./test/test_chinese_fonts.sh

# 清除浏览器缓存
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'

# 重启浏览器
docker exec browser-platform supervisorctl restart bb-browser-api
```

### 问题：浏览器无法启动

```bash
# 清理锁文件
docker exec browser-platform bash -c 'rm -f /root/.bb-browser/browser/user-data/Singleton*'

# 重启 API
docker exec browser-platform supervisorctl restart bb-browser-api
```

### 问题：noVNC 黑屏

```bash
# 重启窗口管理器
docker exec browser-platform supervisorctl restart fluxbox

# 重启所有显示相关服务
docker exec browser-platform supervisorctl restart xvfb fluxbox x11vnc websockify
```

### 诊断命令

```bash
# 检查进程
docker exec browser-platform supervisorctl status

# 检查端口
docker exec browser-platform netstat -tlnp | grep -E '5900|6080|18888'

# 测试 VNC 连接
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'

# 测试 X11 显示
docker exec browser-platform bash -c 'DISPLAY=:99 xdpyinfo | head -20'

# 查看错误日志
docker exec browser-platform tail -50 /var/log/supervisor/x11vnc_err.log
docker exec browser-platform tail -50 /var/log/supervisor/websockify_err.log
```

## 📝 日志位置

### 容器内日志

```bash
# Supervisord 日志目录
/var/log/supervisor/

# 各服务日志
/var/log/supervisor/xvfb.log
/var/log/supervisor/x11vnc.log
/var/log/supervisor/websockify.log
/var/log/supervisor/bb-browser-api.log

# 错误日志
/var/log/supervisor/x11vnc_err.log
/var/log/supervisor/websockify_err.log
```

### 查看日志

```bash
# 实时查看
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 查看最近 100 行
docker exec browser-platform tail -100 /var/log/supervisor/x11vnc.log

# 查看所有错误日志
docker exec browser-platform bash -c 'tail -50 /var/log/supervisor/*_err.log'
```

## 🔄 更新部署

```bash
# 1. 停止容器
docker-compose down

# 2. 拉取最新代码
git pull

# 3. 重新构建
docker-compose build --no-cache

# 4. 启动容器
docker-compose up -d

# 5. 验证
./test/test_services.sh
```

## 🛡️ 监控

### 启动监控

```bash
# 前台运行
./test/monitor.sh

# 后台运行
./test/monitor.sh &

# 自定义间隔（60 秒）
./test/monitor.sh -i 60

# 作为 systemd 服务
sudo systemctl start bb-browser-monitor
```

### 查看监控日志

```bash
# 如果使用后台运行
tail -f /var/log/bb-browser-monitor.log

# 如果使用 systemd
sudo journalctl -u bb-browser-monitor -f
```

## 🔐 安全配置

### 修改 Token

编辑 `docker-compose.yaml`：
```yaml
environment:
  NOVNC_TOKEN: "your-secure-token"
```

重启容器：
```bash
docker-compose down
docker-compose up -d
```

### 限制访问

编辑 `docker-compose.yaml`：
```yaml
ports:
  - "127.0.0.1:6080:6080"  # 仅本地访问
```

## 📦 备份和恢复

### 备份

```bash
# 备份 Chrome 配置
tar -czf chrome-profile-backup-$(date +%Y%m%d).tar.gz /data/bb-browser-api/chrome-profile

# 备份配置文件
tar -czf config-backup-$(date +%Y%m%d).tar.gz docker-compose.yaml supervisord.conf Dockerfile
```

### 恢复

```bash
# 停止服务
docker-compose down

# 恢复数据
tar -xzf chrome-profile-backup-20260518.tar.gz -C /

# 启动服务
docker-compose up -d
```

## 🧪 测试

```bash
# 完整测试
./test/test_services.sh

# 测试 VNC 连接
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'

# 测试 API
curl http://localhost:18888/status

# 测试 noVNC
curl http://localhost:6080/vnc.html
```

## 📚 文档

| 文档 | 说明 |
|------|------|
| README.md | 项目主文档 |
| CHANGELOG.md | 更新日志 |
| docs/deployment.md | 部署指南 |
| docs/troubleshooting.md | 故障排查 |
| docs/systemd-setup.md | Systemd 配置 |
| docs/project-structure.md | 项目结构 |

## 💡 提示

### 性能优化

```bash
# 调整共享内存（编辑 docker-compose.yaml）
shm_size: 4gb

# 清理缓存
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'
```

### 调试技巧

```bash
# 进入容器
docker exec -it browser-platform bash

# 手动启动服务（调试用）
supervisorctl stop x11vnc
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -listen 0.0.0.0 -v

# 查看进程树
ps auxf
```

## 🆘 获取帮助

1. **查看文档**：`docs/troubleshooting.md`
2. **运行诊断**：`./test/test_services.sh`
3. **查看日志**：`docker exec browser-platform supervisorctl status`
4. **生成诊断报告**：
```bash
docker exec browser-platform supervisorctl status > diagnosis.txt
docker exec browser-platform ps auxf >> diagnosis.txt
docker logs browser-platform >> diagnosis.txt
```

## 🎯 最佳实践

1. **开发环境**：使用 `docker-compose up -d`
2. **生产环境**：使用 `sudo ./deploy-systemd.sh`
3. **定期备份**：每周备份 Chrome 配置
4. **监控日志**：定期查看错误日志
5. **及时更新**：定期拉取最新代码
6. **资源监控**：使用 `docker stats browser-platform`

## 📞 紧急恢复

```bash
# 一键恢复流程
docker exec browser-platform supervisorctl restart all
sleep 5
./test/test_services.sh

# 如果还不行
docker-compose restart
sleep 10
./test/test_services.sh

# 如果还不行
docker-compose down
docker-compose up -d
sleep 15
./test/test_services.sh
```

---

**记住**：大多数问题都可以通过重启相关服务解决，无需重启整个容器！
