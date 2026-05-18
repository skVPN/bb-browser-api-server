# 故障排查指南

## 核心问题：Connection refused to localhost:5900

这是最常见的问题，通常发生在容器运行一段时间后。

### 根本原因

1. **x11vnc 进程崩溃或退出**
2. **Xvfb 显示服务器停止**
3. **进程启动顺序错误**
4. **资源不足导致进程被杀**

### 解决方案

#### 方案 1: 重启 x11vnc（最快）

```bash
docker exec browser-platform supervisorctl restart x11vnc
```

等待 2-3 秒后测试：
```bash
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'
```

#### 方案 2: 重启相关服务链

```bash
# 按顺序重启
docker exec browser-platform supervisorctl restart xvfb
sleep 2
docker exec browser-platform supervisorctl restart x11vnc
sleep 2
docker exec browser-platform supervisorctl restart websockify
```

#### 方案 3: 重启所有服务

```bash
docker exec browser-platform supervisorctl restart all
```

#### 方案 4: 重启容器（最彻底）

```bash
docker-compose restart
```

### 诊断步骤

#### 1. 检查进程状态

```bash
docker exec browser-platform supervisorctl status
```

期望输出：
```
xvfb                             RUNNING   pid 123, uptime 1:23:45
fluxbox                          RUNNING   pid 124, uptime 1:23:43
x11vnc                           RUNNING   pid 125, uptime 1:23:41
websockify                       RUNNING   pid 126, uptime 1:23:39
bb-browser-api                   RUNNING   pid 127, uptime 1:23:37
```

如果看到 `FATAL` 或 `EXITED`，说明进程异常退出。

#### 2. 查看错误日志

```bash
# x11vnc 错误日志
docker exec browser-platform tail -50 /var/log/supervisor/x11vnc_err.log

# Xvfb 错误日志
docker exec browser-platform tail -50 /var/log/supervisor/xvfb_err.log

# websockify 错误日志
docker exec browser-platform tail -50 /var/log/supervisor/websockify_err.log
```

#### 3. 检查端口监听

```bash
docker exec browser-platform netstat -tlnp | grep -E '5900|6080'
```

期望输出：
```
tcp        0      0 0.0.0.0:5900            0.0.0.0:*               LISTEN      125/x11vnc
tcp        0      0 0.0.0.0:6080            0.0.0.0:*               LISTEN      126/python
```

#### 4. 测试 VNC 连接

```bash
# 测试端口连通性
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'

# 测试 X11 显示
docker exec browser-platform bash -c 'DISPLAY=:99 xdpyinfo | head -20'
```

#### 5. 检查资源使用

```bash
# 容器资源使用
docker stats browser-platform --no-stream

# 容器内存使用
docker exec browser-platform free -h

# 磁盘使用
docker exec browser-platform df -h
```

## 常见错误及解决方案

### 错误 1: x11vnc 启动失败

**错误信息**：
```
XOpenDisplay(":99") failed.
```

**原因**: Xvfb 未运行或 DISPLAY 变量错误

**解决**：
```bash
# 检查 Xvfb
docker exec browser-platform supervisorctl status xvfb

# 重启 Xvfb
docker exec browser-platform supervisorctl restart xvfb
sleep 2

# 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc
```

### 错误 2: websockify 连接失败

**错误信息**：
```
Failed to connect to localhost:5900: [Errno 111] Connection refused
```

**原因**: x11vnc 未运行或端口未监听

**解决**：
```bash
# 1. 确认 x11vnc 运行
docker exec browser-platform supervisorctl status x11vnc

# 2. 确认端口监听
docker exec browser-platform netstat -tln | grep 5900

# 3. 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc
sleep 2

# 4. 重启 websockify
docker exec browser-platform supervisorctl restart websockify
```

### 错误 3: noVNC 黑屏

**可能原因**：
1. fluxbox 未运行
2. Chrome 未启动
3. 显示权限问题

**解决**：
```bash
# 检查所有服务
docker exec browser-platform supervisorctl status

# 重启窗口管理器
docker exec browser-platform supervisorctl restart fluxbox

# 重启浏览器 API
docker exec browser-platform supervisorctl restart bb-browser-api

# 测试显示
docker exec browser-platform bash -c 'DISPLAY=:99 xterm &'
```

### 错误 4: Token 验证失败

**错误信息**：
```
Token not found
```

**解决**：
```bash
# 检查 token 配置
docker exec browser-platform cat /etc/novnc/tokenfile

# 重新生成 token 文件
docker exec browser-platform bash -c 'echo "tec: localhost:5900" > /etc/novnc/tokenfile'

# 重启 websockify
docker exec browser-platform supervisorctl restart websockify
```

### 错误 5: Chrome 无法启动

**错误信息**：
```
Failed to move to new namespace
```

**原因**: Chrome 沙箱问题或锁文件

**解决**：
```bash
# 清理锁文件
docker exec browser-platform bash -c 'rm -f /root/.bb-browser/browser/user-data/Singleton*'

# 清理崩溃文件
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Crash*'

# 重启服务
docker exec browser-platform supervisorctl restart bb-browser-api
```

### 错误 6: 内存不足

**症状**: 进程频繁被杀，OOM 错误

**解决**：
```bash
# 1. 增加共享内存
# 编辑 docker-compose.yaml
shm_size: 4gb

# 2. 限制 Chrome 进程数
# 在启动参数中添加
--max-old-space-size=2048

# 3. 清理缓存
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'

# 4. 重启容器
docker-compose restart
```

## 预防措施

### 1. 启用自动重启（已配置）

supervisord 配置中已包含：
```ini
autorestart=true
```

### 2. 定期健康检查

创建 cron 任务：
```bash
# 每 5 分钟检查一次
*/5 * * * * /root/bb-browser-api-server/test/test_services.sh > /var/log/health-check.log 2>&1
```

### 3. 监控日志大小

```bash
# 查看日志大小
docker exec browser-platform du -sh /var/log/supervisor/

# 清理旧日志
docker exec browser-platform bash -c 'find /var/log/supervisor/ -name "*.log" -size +100M -exec truncate -s 0 {} \;'
```

### 4. 配置告警

使用监控工具（如 Prometheus）监控：
- 进程状态
- 端口可用性
- 资源使用率
- 错误日志

### 5. 定期重启

如果服务长期运行，建议定期重启：
```bash
# 每周重启一次
0 3 * * 0 docker-compose restart
```

## 调试技巧

### 1. 实时查看日志

```bash
# 多窗口同时查看
# 窗口 1: supervisord 主日志
docker exec browser-platform tail -f /var/log/supervisor/supervisord.log

# 窗口 2: x11vnc 日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 窗口 3: websockify 日志
docker exec browser-platform tail -f /var/log/supervisor/websockify.log
```

### 2. 手动启动服务（调试模式）

```bash
# 进入容器
docker exec -it browser-platform bash

# 停止 supervisord 管理的服务
supervisorctl stop x11vnc

# 手动启动查看详细输出
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -listen 0.0.0.0 -v
```

### 3. 网络诊断

```bash
# 检查容器网络
docker network inspect browser-platform_net

# 测试端口转发
curl -v http://localhost:6080/vnc.html

# 检查防火墙
docker exec browser-platform iptables -L
```

### 4. 进程树查看

```bash
docker exec browser-platform ps auxf
```

### 5. 系统调用跟踪

```bash
# 跟踪 x11vnc 进程
docker exec browser-platform strace -p $(pgrep x11vnc)
```

## 快速参考

### 常用命令

```bash
# 查看状态
docker exec browser-platform supervisorctl status

# 重启服务
docker exec browser-platform supervisorctl restart x11vnc

# 查看日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 测试连接
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'

# 完整测试
./test/test_services.sh
```

### 紧急恢复流程

```bash
# 1. 检查状态
docker exec browser-platform supervisorctl status

# 2. 重启失败的服务
docker exec browser-platform supervisorctl restart all

# 3. 如果还不行，重启容器
docker-compose restart

# 4. 如果还不行，重建容器
docker-compose down
docker-compose up -d

# 5. 验证
./test/test_services.sh
```

## 获取帮助

如果以上方法都无法解决问题：

1. **收集诊断信息**：
```bash
# 生成诊断报告
docker exec browser-platform supervisorctl status > diagnosis.txt
docker exec browser-platform ps auxf >> diagnosis.txt
docker exec browser-platform netstat -tlnp >> diagnosis.txt
docker logs browser-platform >> diagnosis.txt
```

2. **查看完整日志**：
```bash
docker exec browser-platform tar -czf /tmp/logs.tar.gz /var/log/supervisor/
docker cp browser-platform:/tmp/logs.tar.gz ./
```

3. **检查 Docker 环境**：
```bash
docker version
docker-compose version
docker info
```
