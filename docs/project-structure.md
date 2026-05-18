# 项目结构说明

## 目录结构

```
bb-browser-api-server/
├── README.md                    # 项目主文档
├── docker-compose.yaml          # Docker Compose 配置
├── Dockerfile                   # Docker 镜像构建文件
├── supervisord.conf             # Supervisord 进程管理配置
├── start.sh                     # 手动启动脚本（调试用）
├── quick-start.sh               # 一键启动脚本
├── deploy-systemd.sh            # Systemd 服务部署脚本
├── .gitignore                   # Git 忽略文件配置
│
├── docs/                        # 文档目录
│   ├── deployment.md            # 部署和更新指南
│   ├── troubleshooting.md       # 故障排查指南
│   ├── systemd-setup.md         # Systemd 配置指南
│   └── project-structure.md     # 项目结构说明（本文件）
│
└── test/                        # 测试脚本目录
    ├── test_services.sh         # 服务健康检查测试
    └── monitor.sh               # 持续监控脚本
```

## 核心文件说明

### 1. docker-compose.yaml

Docker Compose 配置文件，定义了服务的运行方式。

**关键配置**：
- 端口映射：18888（API）、19825（CDP）、6080（noVNC）、5900（VNC）
- 共享内存：3GB（Chrome 需要）
- 环境变量：BB_DAEMON_HOST、NOVNC_TOKEN
- 数据卷：Chrome 配置文件持久化
- 网络：独立的 bridge 网络

**修改建议**：
- 调整端口映射以避免冲突
- 修改 NOVNC_TOKEN 增强安全性
- 调整 shm_size 根据实际需求
- 修改数据卷路径

### 2. Dockerfile

Docker 镜像构建文件，定义了容器环境。

**构建层次**：
1. 基础镜像：Ubuntu 22.04
2. 安装系统依赖：Xvfb、x11vnc、noVNC、websockify
3. 安装 Chrome 浏览器
4. 安装 Node.js 和 bb-browser-api
5. 安装 supervisord
6. 配置 noVNC UI
7. 复制配置文件

**优化点**：
- 使用多阶段构建减小镜像大小
- 合并 RUN 命令减少层数
- 清理 apt 缓存

### 3. supervisord.conf

Supervisord 进程管理配置，定义了所有服务进程。

**管理的进程**：
1. **xvfb** (优先级 10)
   - 虚拟显示服务器
   - 监听 :99 显示
   - 分辨率 1920x1080x24

2. **fluxbox** (优先级 20)
   - 轻量级窗口管理器
   - 依赖 Xvfb

3. **x11vnc** (优先级 30)
   - VNC 服务器
   - 监听 5900 端口
   - 依赖 Xvfb

4. **websockify** (优先级 40)
   - WebSocket 代理
   - 监听 6080 端口
   - 提供 noVNC Web 界面
   - 依赖 x11vnc

5. **bb-browser-api** (优先级 50)
   - 浏览器自动化 API
   - 监听 18888 和 19825 端口
   - 依赖 Xvfb

**配置特点**：
- `autorestart=true`: 自动重启崩溃进程
- `priority`: 控制启动顺序
- `startsecs`: 启动稳定时间
- 独立的日志文件

### 4. start.sh

手动启动脚本，用于调试。

**功能**：
- 按顺序启动所有服务
- 清理 Chrome 锁文件
- 配置环境变量
- 生成 noVNC token 文件

**使用场景**：
- 容器内手动调试
- 理解服务启动流程
- 临时测试

**注意**：生产环境使用 supervisord，不使用此脚本。

### 5. quick-start.sh

一键启动脚本，简化部署流程。

**功能**：
- 检查 Docker 环境
- 创建数据目录
- 构建 Docker 镜像
- 启动容器
- 运行健康检查

**适用场景**：
- 首次部署
- 快速测试
- 开发环境

### 6. deploy-systemd.sh

Systemd 服务部署脚本。

**功能**：
- 创建 systemd 服务文件
- 配置开机自启
- 设置日志轮转
- 启动监控服务

**适用场景**：
- 生产环境部署
- 需要开机自启
- 需要系统级管理

## 测试脚本说明

### test/test_services.sh

服务健康检查测试脚本。

**检查项目**：
1. 容器运行状态
2. Supervisord 进程状态
3. 各服务进程是否运行
4. 端口监听状态
5. X11 显示可用性
6. VNC 连接测试
7. noVNC token 配置
8. HTTP 端点可访问性
9. 错误日志检查
10. 服务重启测试

**使用方式**：
```bash
./test/test_services.sh
```

**输出**：
- ✓ 绿色：测试通过
- ✗ 红色：测试失败
- 详细的错误信息

### test/monitor.sh

持续监控脚本，自动检测和修复问题。

**监控功能**：
- 定期检查服务状态（默认 30 秒）
- 自动重启失败的服务
- 记录监控日志
- 发送告警通知

**自动修复**：
- 单个进程崩溃 → 重启该进程
- VNC 连接失败 → 重启服务链
- 连续失败 → 记录告警

**使用方式**：
```bash
# 前台运行
./test/monitor.sh

# 后台运行
./test/monitor.sh &

# 自定义检查间隔
./test/monitor.sh -i 60

# 作为 systemd 服务运行
sudo systemctl start bb-browser-monitor
```

## 文档说明

### docs/deployment.md

部署和更新指南，包含：
- 首次部署步骤
- 更新部署方案
- 从旧版本迁移
- 故障恢复流程
- 监控和维护
- 备份和恢复
- 安全建议

### docs/troubleshooting.md

故障排查指南，包含：
- Connection refused 问题详解
- 常见错误及解决方案
- 诊断步骤
- 预防措施
- 调试技巧
- 快速参考命令

### docs/systemd-setup.md

Systemd 配置指南，包含：
- Docker Compose 服务配置
- 监控服务配置
- 定时健康检查配置
- 日志轮转配置
- 完整部署流程
- 监控和维护
- 故障排查
- 卸载步骤

### docs/project-structure.md

项目结构说明（本文件），包含：
- 目录结构
- 核心文件说明
- 测试脚本说明
- 文档说明
- 配置文件说明

## 配置文件说明

### .gitignore

Git 忽略文件配置。

**忽略内容**：
- Chrome 配置文件
- 日志文件
- 临时文件
- IDE 配置
- 备份文件

### .claude/settings.local.json

Claude AI 配置文件（如果使用 Claude）。

## 数据持久化

### Chrome 配置文件

**默认路径**：
```
/data/bb-browser-api/chrome-profile
```

**包含内容**：
- 浏览器配置
- Cookie 和会话
- 扩展程序
- 书签和历史

**备份建议**：
```bash
tar -czf chrome-profile-backup.tar.gz /data/bb-browser-api/chrome-profile
```

### 日志文件

**Supervisord 日志**：
```
/var/log/supervisor/
├── supervisord.log          # 主日志
├── xvfb.log                 # Xvfb 输出
├── xvfb_err.log             # Xvfb 错误
├── fluxbox.log              # fluxbox 输出
├── fluxbox_err.log          # fluxbox 错误
├── x11vnc.log               # x11vnc 输出
├── x11vnc_err.log           # x11vnc 错误
├── websockify.log           # websockify 输出
├── websockify_err.log       # websockify 错误
├── bb-browser-api.log       # API 输出
└── bb-browser-api_err.log   # API 错误
```

**监控日志**：
```
/var/log/bb-browser-monitor.log   # 监控日志
/var/log/bb-browser-alerts.log    # 告警日志
```

## 端口使用

| 端口 | 服务 | 说明 |
|------|------|------|
| 18888 | bb-browser-api | HTTP API 接口 |
| 19825 | Chrome CDP | Chrome DevTools Protocol |
| 6080 | noVNC | Web VNC 界面 |
| 5900 | x11vnc | VNC 直连端口 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DISPLAY | :99 | X11 显示编号 |
| BB_DAEMON_HOST | 0.0.0.0 | API 监听地址 |
| NOVNC_TOKEN | tec | noVNC 访问令牌 |

## 依赖关系

```
Xvfb (显示服务器)
  ↓
fluxbox (窗口管理器)
  ↓
x11vnc (VNC 服务器)
  ↓
websockify (WebSocket 代理)

Xvfb (显示服务器)
  ↓
bb-browser-api (浏览器 API)
```

## 开发建议

### 本地开发

1. 修改代码
2. 重新构建镜像：`docker-compose build`
3. 重启容器：`docker-compose up -d`
4. 查看日志：`docker-compose logs -f`

### 调试技巧

1. **进入容器**：
```bash
docker exec -it browser-platform bash
```

2. **查看进程状态**：
```bash
supervisorctl status
```

3. **查看实时日志**：
```bash
tail -f /var/log/supervisor/x11vnc.log
```

4. **手动重启服务**：
```bash
supervisorctl restart x11vnc
```

### 性能优化

1. **调整共享内存**：
```yaml
shm_size: 4gb
```

2. **限制资源使用**：
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

3. **清理缓存**：
```bash
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'
```

## 安全建议

1. **修改默认 Token**
2. **限制网络访问**
3. **使用反向代理**
4. **定期更新镜像**
5. **监控异常访问**

## 扩展功能

### 添加新服务

在 `supervisord.conf` 中添加：

```ini
[program:new-service]
command=/path/to/command
autostart=true
autorestart=true
priority=60
stdout_logfile=/var/log/supervisor/new-service.log
stderr_logfile=/var/log/supervisor/new-service_err.log
```

### 集成监控系统

- Prometheus + Grafana
- ELK Stack
- Datadog
- New Relic

### 负载均衡

使用 Docker Swarm 或 Kubernetes 进行横向扩展。

## 常见问题

### Q: 如何修改端口？

A: 编辑 `docker-compose.yaml` 中的 ports 配置。

### Q: 如何增加内存？

A: 编辑 `docker-compose.yaml` 中的 shm_size 配置。

### Q: 如何查看日志？

A: 使用 `docker-compose logs -f` 或进入容器查看 `/var/log/supervisor/`。

### Q: 如何备份数据？

A: 备份 `/data/bb-browser-api/chrome-profile` 目录。

### Q: 如何更新版本？

A: 参考 `docs/deployment.md` 中的更新流程。
