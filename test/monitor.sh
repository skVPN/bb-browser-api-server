#!/bin/bash
# 持续监控脚本 - 检测服务异常并自动恢复

CONTAINER_NAME="browser-platform"
CHECK_INTERVAL=30  # 检查间隔（秒）
LOG_FILE="/var/log/bb-browser-monitor.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检查容器是否运行
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        log "${RED}✗ 容器未运行${NC}"
        return 1
    fi
    return 0
}

# 检查进程状态
check_process() {
    local process_name=$1
    if docker exec "$CONTAINER_NAME" supervisorctl status "$process_name" | grep -q RUNNING; then
        return 0
    else
        log "${RED}✗ $process_name 未运行${NC}"
        return 1
    fi
}

# 检查端口
check_port() {
    local port=$1
    local service_name=$2
    if docker exec "$CONTAINER_NAME" netstat -tln | grep -q ":$port"; then
        return 0
    else
        log "${RED}✗ $service_name 端口 $port 未监听${NC}"
        return 1
    fi
}

# 检查 VNC 连接
check_vnc_connection() {
    if docker exec "$CONTAINER_NAME" bash -c 'timeout 2 nc -zv localhost 5900' &>/dev/null; then
        return 0
    else
        log "${RED}✗ VNC 连接失败${NC}"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service_name=$1
    log "${YELLOW}尝试重启 $service_name${NC}"
    docker exec "$CONTAINER_NAME" supervisorctl restart "$service_name"
    sleep 3
    
    if check_process "$service_name"; then
        log "${GREEN}✓ $service_name 重启成功${NC}"
        return 0
    else
        log "${RED}✗ $service_name 重启失败${NC}"
        return 1
    fi
}

# 重启服务链
restart_service_chain() {
    log "${YELLOW}重启服务链: xvfb -> x11vnc -> websockify${NC}"
    
    docker exec "$CONTAINER_NAME" supervisorctl restart xvfb
    sleep 2
    docker exec "$CONTAINER_NAME" supervisorctl restart x11vnc
    sleep 2
    docker exec "$CONTAINER_NAME" supervisorctl restart websockify
    sleep 2
    
    if check_vnc_connection; then
        log "${GREEN}✓ 服务链重启成功${NC}"
        return 0
    else
        log "${RED}✗ 服务链重启失败${NC}"
        return 1
    fi
}

# 发送告警（可扩展）
send_alert() {
    local message=$1
    log "${RED}[告警] $message${NC}"
    
    # 这里可以添加告警通知，例如：
    # - 发送邮件
    # - 调用 Webhook
    # - 发送到监控系统
    
    # 示例：写入告警文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> /var/log/bb-browser-alerts.log
}

# 主监控循环
monitor() {
    log "${GREEN}开始监控服务...${NC}"
    
    local consecutive_failures=0
    local max_consecutive_failures=3
    
    while true; do
        # 检查容器
        if ! check_container; then
            send_alert "容器未运行"
            sleep "$CHECK_INTERVAL"
            continue
        fi
        
        # 检查关键进程
        local all_ok=true
        
        # 检查 Xvfb
        if ! check_process "xvfb"; then
            all_ok=false
            restart_service "xvfb"
        fi
        
        # 检查 x11vnc
        if ! check_process "x11vnc"; then
            all_ok=false
            restart_service "x11vnc"
        fi
        
        # 检查 websockify
        if ! check_process "websockify"; then
            all_ok=false
            restart_service "websockify"
        fi
        
        # 检查 bb-browser-api
        if ! check_process "bb-browser-api"; then
            all_ok=false
            restart_service "bb-browser-api"
        fi
        
        # 检查端口
        if ! check_port "5900" "VNC"; then
            all_ok=false
            restart_service "x11vnc"
        fi
        
        if ! check_port "6080" "noVNC"; then
            all_ok=false
            restart_service "websockify"
        fi
        
        # 检查 VNC 连接
        if ! check_vnc_connection; then
            all_ok=false
            if ! restart_service_chain; then
                send_alert "VNC 连接恢复失败"
            fi
        fi
        
        # 连续失败计数
        if [ "$all_ok" = false ]; then
            consecutive_failures=$((consecutive_failures + 1))
            log "${YELLOW}连续失败次数: $consecutive_failures${NC}"
            
            if [ $consecutive_failures -ge $max_consecutive_failures ]; then
                send_alert "服务连续失败 $consecutive_failures 次，可能需要人工介入"
                consecutive_failures=0
            fi
        else
            if [ $consecutive_failures -gt 0 ]; then
                log "${GREEN}✓ 服务已恢复正常${NC}"
            fi
            consecutive_failures=0
        fi
        
        # 等待下次检查
        sleep "$CHECK_INTERVAL"
    done
}

# 显示使用说明
usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --interval SECONDS    设置检查间隔（默认: 30 秒）"
    echo "  -l, --log FILE           设置日志文件路径"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                       # 使用默认设置"
    echo "  $0 -i 60                 # 每 60 秒检查一次"
    echo "  $0 -l /tmp/monitor.log   # 自定义日志路径"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

# 捕获退出信号
trap 'log "监控服务停止"; exit 0' SIGINT SIGTERM

# 启动监控
log "=========================================="
log "BB Browser API Server 监控服务启动"
log "检查间隔: $CHECK_INTERVAL 秒"
log "日志文件: $LOG_FILE"
log "=========================================="

monitor
