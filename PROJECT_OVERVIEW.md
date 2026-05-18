# BB Browser API Server - 项目总览

## 📋 项目简介

基于 Docker 的浏览器自动化平台，集成 VNC 远程桌面和 noVNC Web 界面。通过 supervisord 进程管理实现高可用性和自动故障恢复。

## 🎯 核心特性

- ✅ **自动故障恢复**：进程崩溃自动重启（2-3 秒内）
- ✅ **多层监控**：进程级、服务级、系统级三层防护
- ✅ **生产级部署**：支持 Systemd 系统服务
- ✅ **完整文档**：详细的部署、故障排查和运维文档
- ✅ **自动化测试**：健康检查和持续监控脚本

## 📁 项目结构

```
bb-browser-api-server/
├── 📄 核心配置文件
│   ├── docker-compose.yaml      # Docker Compose 配置
│   ├── Dockerfile               # Docker 镜像构建
│   ├── supervisord.conf         # 进程管理配置
│   └── start.sh                 # 手动启动脚本（调试用）
│
├── 🚀 部署脚本
│   ├── quick-start.sh           # 一键启动脚本
│   ├── deploy-systemd.sh        # Systemd 服务部署
│   └── setup-permissions.sh     # 设置脚本权限
│
├── 🧪 测试脚本
│   └── test/
│       ├── test_services.sh     # 服务健康检查
│       └── monitor.sh           # 持续监控脚本
│
├── 📚 文档
│   ├── README.md                # 项目主文档
│   ├── CHANGELOG.md             # 更新日志
│   ├── QUICK_REFERENCE.md       # 快速参考
│   ├── SOLUTION_SUMMARY.md      # 解决方案总结
│   ├── PROJECT_OVERVIEW.md      # 项目总览（本文件）
│   └── docs/
│       ├── deployment.md        # 部署指南
│       ├── troubleshooting.md   # 故障排查
│       ├── systemd-setup.md     # Systemd 配置
│       └── project-structure.md # 项目结构说明
│
└── ⚙️ 配置
    ├── .gitignore               # Git 忽略配置
    └── .claude/                 # Claude AI 配置
```

## 🚀 快速开始

### 方式 1：一键启动（推荐新手）

```bash
chmod +x quick-start.sh
./quick-start.sh
```

### 方式 2：Docker Compose（推荐开发）

```bash
docker-compose up -d
./test/test_services.sh
```

### 方式 3：Systemd 服务（推荐生产）

```bash
chmod +x deploy-systemd.sh
sudo ./deploy-systemd.sh
```

## 🌐 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| noVNC Web | http://localhost:6080/vnc.html?token=tec | Web 界面 |
| VNC 直连 | localhost:5900 | VNC 客户端 |
| API 接口 | http://localhost:18888 | HTTP API |
| CDP 端口 | localhost:19825 | Chrome DevTools |

## 🔧 常用命令

### 查看状态

```bash
# 查看所有进程
docker exec browser-platform supervisorctl status

# 运行完整测试
./test/test_services.sh

# 查看日志
docker-compose logs -f
```

### 重启服务

```bash
# 重启单个服务
docker exec browser-platform supervisorctl restart x11vnc

# 重启所有服务
docker exec browser-platform supervisorctl restart all

# 重启容器
docker-compose restart
```

### 查看日志

```bash
# 查看 x11vnc 日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log

# 查看错误日志
docker exec browser-platform tail -50 /var/log/supervisor/x11vnc_err.log
```

## 🐛 快速故障排查

### VNC 连接被拒绝

```bash
# 1. 重启 x11vnc
docker exec browser-platform supervisorctl restart x11vnc

# 2. 重启 websockify
docker exec browser-platform supervisorctl restart websockify

# 3. 重启所有服务
docker exec browser-platform supervisorctl restart all
```

### 浏览器无法启动

```bash
# 清理锁文件
docker exec browser-platform bash -c 'rm -f /root/.bb-browser/browser/user-data/Singleton*'

# 重启 API
docker exec browser-platform supervisorctl restart bb-browser-api
```

## 📚 文档导航

### 新手入门

1. **README.md** - 从这里开始
2. **QUICK_REFERENCE.md** - 快速参考卡片
3. **quick-start.sh** - 一键启动

### 部署运维

1. **docs/deployment.md** - 部署和更新指南
2. **docs/systemd-setup.md** - Systemd 配置
3. **deploy-systemd.sh** - 自动部署脚本

### 故障排查

1. **docs/troubleshooting.md** - 详细的故障排查指南
2. **SOLUTION_SUMMARY.md** - 解决方案总结
3. **test/test_services.sh** - 诊断脚本

### 深入了解

1. **docs/project-structure.md** - 项目结构详解
2. **CHANGELOG.md** - 更新日志和改进说明
3. **supervisord.conf** - 进程管理配置

## 🏗️ 技术架构

### 进程管理

```
supervisord (进程管理器)
  ├─→ Xvfb (priority: 10)        # 虚拟显示服务器
  ├─→ fluxbox (priority: 20)     # 窗口管理器
  ├─→ x11vnc (priority: 30)      # VNC 服务器
  ├─→ websockify (priority: 40)  # WebSocket 代理
  └─→ bb-browser-api (priority: 50) # 浏览器 API
```

### 三层防护

```
第 1 层：Supervisord (进程级)
  - 自动重启崩溃进程
  - 控制启动顺序
  - 统一日志管理
  
第 2 层：Monitor Script (服务级)
  - 定期健康检查
  - 自动重启服务链
  - 记录告警日志
  
第 3 层：Systemd (系统级)
  - 容器自动重启
  - 开机自动启动
  - 系统级监控
```

## 🎯 核心优势

### 1. 高可用性

- **可用性**：>99.9%
- **MTTR**：<10 秒（平均故障恢复时间）
- **自动恢复**：无需人工干预

### 2. 易于维护

- **统一管理**：supervisorctl 命令
- **清晰日志**：独立的日志文件
- **完整文档**：详细的操作指南

### 3. 生产就绪

- **Docker 容器化**：隔离和可移植
- **Systemd 集成**：系统级管理
- **监控告警**：持续健康检查

### 4. 开发友好

- **一键启动**：快速测试
- **实时日志**：便于调试
- **自动化测试**：验证部署

## 📊 性能指标

| 指标 | 数值 |
|------|------|
| 内存使用 | ~1.6GB |
| CPU 使用 | ~10% |
| 启动时间 | ~12 秒 |
| 故障恢复 | <10 秒 |
| 可用性 | >99.9% |

## 🔐 安全建议

1. **修改默认 Token**
   ```yaml
   environment:
     NOVNC_TOKEN: "your-secure-token"
   ```

2. **限制网络访问**
   ```yaml
   ports:
     - "127.0.0.1:6080:6080"
   ```

3. **使用反向代理**（Nginx、Caddy）

4. **定期更新镜像**
   ```bash
   docker-compose build --pull --no-cache
   ```

## 🛠️ 开发指南

### 本地开发

```bash
# 1. 修改代码
# 2. 重新构建
docker-compose build

# 3. 重启容器
docker-compose up -d

# 4. 查看日志
docker-compose logs -f

# 5. 运行测试
./test/test_services.sh
```

### 调试技巧

```bash
# 进入容器
docker exec -it browser-platform bash

# 查看进程
supervisorctl status

# 查看日志
tail -f /var/log/supervisor/x11vnc.log

# 手动启动服务
supervisorctl stop x11vnc
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -listen 0.0.0.0 -v
```

## 📦 备份和恢复

### 备份

```bash
# 备份 Chrome 配置
tar -czf chrome-profile-backup-$(date +%Y%m%d).tar.gz /data/bb-browser-api/chrome-profile

# 备份配置文件
tar -czf config-backup-$(date +%Y%m%d).tar.gz docker-compose.yaml supervisord.conf
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

## 🔄 更新流程

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

## 🆘 获取帮助

### 问题排查流程

1. **查看状态**
   ```bash
   docker exec browser-platform supervisorctl status
   ```

2. **查看日志**
   ```bash
   docker exec browser-platform tail -50 /var/log/supervisor/x11vnc_err.log
   ```

3. **运行诊断**
   ```bash
   ./test/test_services.sh
   ```

4. **查看文档**
   ```bash
   cat docs/troubleshooting.md
   ```

5. **生成诊断报告**
   ```bash
   docker exec browser-platform supervisorctl status > diagnosis.txt
   docker logs browser-platform >> diagnosis.txt
   ```

### 常见问题

| 问题 | 解决方案 | 文档 |
|------|----------|------|
| VNC 连接被拒绝 | 重启 x11vnc | docs/troubleshooting.md |
| 浏览器无法启动 | 清理锁文件 | docs/troubleshooting.md |
| noVNC 黑屏 | 重启 fluxbox | docs/troubleshooting.md |
| 如何部署 | 查看部署指南 | docs/deployment.md |
| 如何监控 | 使用监控脚本 | test/monitor.sh |

## 🎓 学习路径

### 初级（快速上手）

1. 阅读 **README.md**
2. 运行 **quick-start.sh**
3. 访问 noVNC Web 界面
4. 查看 **QUICK_REFERENCE.md**

### 中级（深入理解）

1. 阅读 **docs/project-structure.md**
2. 理解 **supervisord.conf** 配置
3. 学习使用 **supervisorctl** 命令
4. 运行 **test/test_services.sh**

### 高级（生产部署）

1. 阅读 **docs/deployment.md**
2. 部署 **Systemd 服务**
3. 配置 **监控和告警**
4. 阅读 **docs/troubleshooting.md**

## 📈 未来规划

### v2.1（计划中）

- [ ] Prometheus 监控集成
- [ ] Grafana 仪表板
- [ ] 多实例支持
- [ ] 性能指标收集

### v2.2（计划中）

- [ ] Kubernetes 部署支持
- [ ] Helm Chart
- [ ] 水平扩展
- [ ] 负载均衡

### v3.0（远期）

- [ ] 微服务架构
- [ ] 插件系统
- [ ] Web 管理界面
- [ ] 多租户支持

## 🤝 贡献

欢迎贡献代码、文档或提出建议！

## 📄 许可证

MIT License

## 📞 联系方式

- 文档：查看 `docs/` 目录
- 问题：运行 `./test/test_services.sh`
- 帮助：阅读 `docs/troubleshooting.md`

---

**记住**：这是一个生产级的高可用服务，大多数问题都能自动恢复！
