# BB Browser API Server

基于 Docker 的浏览器自动化平台，集成 VNC 远程桌面和 noVNC Web 界面。

> 📖 **快速导航**：[项目总览](PROJECT_OVERVIEW.md) | [快速参考](QUICK_REFERENCE.md) | [解决方案总结](SOLUTION_SUMMARY.md) | [更新日志](CHANGELOG.md)

## 功能特性

- **浏览器自动化**: 使用 bb-browser-api 进行浏览器控制
- **远程桌面**: 通过 VNC 和 noVNC 访问浏览器界面
- **进程管理**: 使用 supervisord 自动监控和重启服务
- **持久化存储**: Chrome 配置文件持久化保存
- **中文字体支持**: 完整的中文字体和 locale 配置

## 端口说明

- `18888`: bb-browser-api HTTP API
- `19825`: Chrome DevTools Protocol (CDP)
- `6080`: noVNC Web 界面
- `5900`: VNC 直连端口

## 快速启动

### 方式 1: 一键启动脚本（最简单）

```bash
chmod +x quick-start.sh
./quick-start.sh
```

### 方式 2: Docker Compose（推荐）

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 方式 3: Systemd 服务（生产环境）

```bash
# 部署为系统服务（需要 root 权限）
chmod +x deploy-systemd.sh
sudo ./deploy-systemd.sh

# 管理服务
sudo systemctl start bb-browser
sudo systemctl stop bb-browser
sudo systemctl status bb-browser

# 查看详细文档
cat docs/systemd-setup.md
```

### 方式 4: 手动调试

```bash
# 进入容器
docker exec -it browser-platform bash

# 手动运行启动脚本
/start.sh
```

## 访问方式

### Web 界面
打开浏览器访问：
```
http://localhost:6080/vnc.html?token=tec
```

### VNC 客户端
使用 VNC 客户端连接：
```
localhost:5900
```

### API 调用
```bash
curl http://localhost:18888/status
```

## 进程管理

容器使用 supervisord 管理所有服务进程，确保服务稳定运行。

### 查看进程状态

```bash
docker exec browser-platform supervisorctl status
```

### 重启单个服务

```bash
# 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc

# 重启 websockify
docker exec browser-platform supervisorctl restart websockify

# 重启所有服务
docker exec browser-platform supervisorctl restart all
```

### 查看服务日志

```bash
# 查看 x11vnc 日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 查看 websockify 日志
docker exec browser-platform tail -f /var/log/supervisor/websockify.log

# 查看 bb-browser-api 日志
docker exec browser-platform tail -f /var/log/supervisor/bb-browser-api.log
```

## 故障排查

### 问题：Connection refused to localhost:5900

**原因**: x11vnc 进程未正常运行

**解决方案**:
```bash
# 1. 检查进程状态
docker exec browser-platform supervisorctl status

# 2. 查看 x11vnc 日志
docker exec browser-platform tail -100 /var/log/supervisor/x11vnc_err.log

# 3. 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc

# 4. 如果问题持续，重启容器
docker-compose restart
```

### 问题：中文显示乱码

**原因**: 缺少中文字体或 locale 配置

**解决方案**:
```bash
# 1. 重新构建镜像（已包含中文字体）
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 2. 验证字体安装
chmod +x test/test_chinese_fonts.sh
./test/test_chinese_fonts.sh

# 3. 清除浏览器缓存
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'

# 4. 重启浏览器 API
docker exec browser-platform supervisorctl restart bb-browser-api

# 详细文档
cat docs/chinese-fonts-guide.md
```

**已安装的中文字体**:
- 文泉驿正黑/微米黑
- Google Noto CJK 字体
- 文鼎 UKai/UMing 字体

### 问题：浏览器无法启动

**检查步骤**:
```bash
# 1. 检查 Xvfb 是否运行
docker exec browser-platform supervisorctl status xvfb

# 2. 检查 DISPLAY 环境变量
docker exec browser-platform bash -c 'echo $DISPLAY'

# 3. 测试 X11 连接
docker exec browser-platform bash -c 'DISPLAY=:99 xdpyinfo'
```

### 问题：noVNC 无法连接

**检查步骤**:
```bash
# 1. 检查 websockify 状态
docker exec browser-platform supervisorctl status websockify

# 2. 检查 token 配置
docker exec browser-platform cat /etc/novnc/tokenfile

# 3. 测试 VNC 端口
docker exec browser-platform netstat -tlnp | grep 5900
```

## 配置说明

### 环境变量

在 `docker-compose.yaml` 中配置：

```yaml
environment:
  BB_DAEMON_HOST: "0.0.0.0"      # API 监听地址
  NOVNC_TOKEN: "tec"              # noVNC 访问令牌
```

### 持久化存储

Chrome 用户数据保存在：
```
/data/bb-browser-api/chrome-profile
```

修改 `docker-compose.yaml` 中的 volumes 配置来更改存储位置。

## 技术架构

```
┌─────────────────────────────────────┐
│         supervisord                 │
│  (进程监控和自动重启)                │
└─────────────────────────────────────┘
           │
           ├─→ Xvfb (:99)
           │   (虚拟显示服务器)
           │
           ├─→ fluxbox
           │   (窗口管理器)
           │
           ├─→ x11vnc (5900)
           │   (VNC 服务器)
           │
           ├─→ websockify (6080)
           │   (WebSocket 代理 + noVNC)
           │
           └─→ bb-browser-api (18888, 19825)
               (浏览器自动化 API)
```

## 核心优势

### 1. 自动恢复机制

使用 **supervisord** 进行进程管理：
- ✅ 自动重启崩溃的进程
- ✅ 确保服务按正确顺序启动
- ✅ 统一的日志收集和管理
- ✅ 实时进程状态监控

### 2. 多层监控

- **进程级监控**: supervisord 自动重启单个进程
- **服务级监控**: monitor.sh 脚本持续检查服务健康状态
- **系统级监控**: systemd 管理容器生命周期

### 3. 问题自动修复

当检测到 `Connection refused` 等问题时：
1. 自动识别故障进程
2. 按依赖顺序重启相关服务
3. 验证服务恢复
4. 记录告警日志

### 4. 生产级部署

- Docker 容器化隔离
- Systemd 开机自启
- 日志自动轮转
- 资源限制和监控

## 开发调试

### 本地构建

```bash
docker build -t bb-browser-api-server .
```

### 进入容器调试

```bash
docker exec -it browser-platform bash
```

### 查看所有日志

```bash
docker exec browser-platform ls -la /var/log/supervisor/
```

## 许可证

MIT
