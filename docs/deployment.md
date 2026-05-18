# 部署和更新指南

## 首次部署

### 1. 准备环境

确保已安装：
- Docker
- Docker Compose

### 2. 克隆或下载项目

```bash
cd /root
git clone <repository-url> bb-browser-api-server
cd bb-browser-api-server
```

### 3. 创建数据目录

```bash
mkdir -p /data/bb-browser-api/chrome-profile
```

### 4. 配置环境变量（可选）

编辑 `docker-compose.yaml` 修改：
- `NOVNC_TOKEN`: noVNC 访问令牌（默认: tec）
- 端口映射
- 数据卷路径

### 5. 构建并启动

```bash
docker-compose up -d
```

### 6. 验证部署

```bash
# 运行测试脚本
chmod +x test/test_services.sh
./test/test_services.sh
```

## 更新部署

### 方案 1: 重新构建（推荐）

当 Dockerfile 或配置文件有更新时：

```bash
# 1. 停止容器
docker-compose down

# 2. 拉取最新代码
git pull

# 3. 重新构建镜像
docker-compose build --no-cache

# 4. 启动新容器
docker-compose up -d

# 5. 验证服务
docker-compose logs -f
```

### 方案 2: 仅重启容器

当只需要重启服务时：

```bash
docker-compose restart
```

### 方案 3: 更新单个服务

```bash
# 重启特定服务
docker exec browser-platform supervisorctl restart x11vnc
docker exec browser-platform supervisorctl restart websockify
```

## 从旧版本迁移

如果你之前使用的是 `start.sh` 启动方式，现在已改为 supervisord：

### 迁移步骤

1. **停止旧容器**
```bash
docker-compose down
```

2. **备份数据**（如果需要）
```bash
cp -r /data/bb-browser-api/chrome-profile /data/bb-browser-api/chrome-profile.backup
```

3. **拉取新代码**
```bash
git pull
```

4. **重新构建**
```bash
docker-compose build --no-cache
```

5. **启动新容器**
```bash
docker-compose up -d
```

6. **验证服务**
```bash
./test/test_services.sh
```

### 主要变化

| 项目 | 旧版本 | 新版本 |
|------|--------|--------|
| 进程管理 | 手动后台启动 | supervisord 自动管理 |
| 进程监控 | 无 | 自动重启崩溃进程 |
| 日志管理 | 分散 | 统一在 /var/log/supervisor/ |
| 启动方式 | /start.sh | supervisord |
| 故障恢复 | 手动重启容器 | 自动恢复 |

## 故障恢复

### 问题：x11vnc 连接被拒绝

**快速修复**：
```bash
# 重启 x11vnc 服务
docker exec browser-platform supervisorctl restart x11vnc

# 如果还不行，重启 websockify
docker exec browser-platform supervisorctl restart websockify
```

**深度排查**：
```bash
# 1. 查看进程状态
docker exec browser-platform supervisorctl status

# 2. 查看错误日志
docker exec browser-platform tail -100 /var/log/supervisor/x11vnc_err.log
docker exec browser-platform tail -100 /var/log/supervisor/websockify_err.log

# 3. 检查端口
docker exec browser-platform netstat -tlnp | grep 5900

# 4. 测试 VNC 连接
docker exec browser-platform bash -c 'timeout 2 nc -zv localhost 5900'
```

### 问题：容器启动后服务未运行

**检查步骤**：
```bash
# 1. 查看容器日志
docker-compose logs browser

# 2. 进入容器检查
docker exec -it browser-platform bash

# 3. 查看 supervisord 日志
tail -f /var/log/supervisor/supervisord.log

# 4. 手动启动服务
supervisorctl start all
```

### 问题：浏览器无法启动

**解决方案**：
```bash
# 1. 清理 Chrome 锁文件
docker exec browser-platform bash -c 'rm -f /root/.bb-browser/browser/user-data/Singleton*'

# 2. 重启 bb-browser-api
docker exec browser-platform supervisorctl restart bb-browser-api

# 3. 检查 DISPLAY
docker exec browser-platform bash -c 'echo $DISPLAY'
docker exec browser-platform bash -c 'DISPLAY=:99 xdpyinfo'
```

## 监控和维护

### 日常检查

```bash
# 每日健康检查
./test/test_services.sh

# 查看资源使用
docker stats browser-platform

# 查看日志
docker-compose logs --tail=100 -f
```

### 日志轮转

supervisord 日志会持续增长，建议配置日志轮转：

```bash
# 进入容器
docker exec -it browser-platform bash

# 手动清理日志
truncate -s 0 /var/log/supervisor/*.log
```

或在 `supervisord.conf` 中配置：
```ini
[program:xvfb]
stdout_logfile=/var/log/supervisor/xvfb.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=3
```

### 性能优化

1. **调整共享内存**
```yaml
# docker-compose.yaml
shm_size: 3gb  # 根据需要调整
```

2. **限制资源使用**
```yaml
# docker-compose.yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

3. **清理 Chrome 缓存**
```bash
# 定期清理
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'
```

## 备份和恢复

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

## 安全建议

1. **修改默认 Token**
```yaml
environment:
  NOVNC_TOKEN: "your-secure-token-here"
```

2. **限制网络访问**
```yaml
ports:
  - "127.0.0.1:6080:6080"  # 仅本地访问
```

3. **使用反向代理**
```nginx
# Nginx 配置示例
location /vnc/ {
    proxy_pass http://localhost:6080/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

4. **定期更新**
```bash
# 更新基础镜像
docker-compose build --pull --no-cache
docker-compose up -d
```

## 生产环境建议

1. **使用 Docker Swarm 或 Kubernetes** 进行编排
2. **配置健康检查**
3. **设置监控告警**（Prometheus + Grafana）
4. **使用持久化存储**（NFS、Ceph 等）
5. **配置日志收集**（ELK、Loki 等）

## 常见问题

### Q: 为什么要使用 supervisord？

A: supervisord 提供：
- 自动重启崩溃的进程
- 统一的进程管理接口
- 日志收集和管理
- 进程启动顺序控制

### Q: 如何查看实时日志？

A: 
```bash
# 查看所有日志
docker-compose logs -f

# 查看特定服务日志
docker exec browser-platform tail -f /var/log/supervisor/x11vnc.log
```

### Q: 如何临时禁用某个服务？

A:
```bash
docker exec browser-platform supervisorctl stop fluxbox
```

### Q: 如何添加新的服务？

A: 在 `supervisord.conf` 中添加新的 `[program:xxx]` 配置段，然后重新构建镜像。
