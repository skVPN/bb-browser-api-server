#!/bin/bash
# 服务健康检查测试脚本

set -e

CONTAINER_NAME="browser-platform"
NOVNC_TOKEN="tec"

echo "=========================================="
echo "BB Browser API Server 服务测试"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_service() {
    local service_name=$1
    local test_command=$2
    
    echo -n "测试 ${service_name}... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        return 1
    fi
}

# 1. 检查容器是否运行
echo "1. 检查容器状态"
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${GREEN}✓ 容器正在运行${NC}"
else
    echo -e "${RED}✗ 容器未运行${NC}"
    exit 1
fi
echo ""

# 2. 检查 supervisord 进程状态
echo "2. 检查 supervisord 进程状态"
docker exec "$CONTAINER_NAME" supervisorctl status
echo ""

# 3. 检查各个服务进程
echo "3. 检查服务进程"
test_service "Xvfb" "docker exec $CONTAINER_NAME pgrep -f 'Xvfb :99'"
test_service "fluxbox" "docker exec $CONTAINER_NAME pgrep -f fluxbox"
test_service "x11vnc" "docker exec $CONTAINER_NAME pgrep -f x11vnc"
test_service "websockify" "docker exec $CONTAINER_NAME pgrep -f websockify"
test_service "bb-browser-api" "docker exec $CONTAINER_NAME pgrep -f bb-browser-api"
echo ""

# 4. 检查 Chrome 安装
echo "4. 检查 Chrome 安装"
if docker exec "$CONTAINER_NAME" which google-chrome > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Chrome 已安装${NC}"
    docker exec "$CONTAINER_NAME" google-chrome --version
else
    echo -e "${RED}✗ Chrome 未安装${NC}"
    echo "这会导致 bb-browser-api 无法启动！"
fi
echo ""

# 5. 检查端口监听
echo "4. 检查端口监听"
test_service "VNC 端口 5900" "docker exec $CONTAINER_NAME netstat -tln | grep -q ':5900'"
test_service "noVNC 端口 6080" "docker exec $CONTAINER_NAME netstat -tln | grep -q ':6080'"
test_service "API 端口 18888" "docker exec $CONTAINER_NAME netstat -tln | grep -q ':18888'"
test_service "CDP 端口 19825" "docker exec $CONTAINER_NAME netstat -tln | grep -q ':19825'"
echo ""

# 5. 检查 X11 显示
echo "5. 检查 X11 显示"
test_service "DISPLAY :99" "docker exec $CONTAINER_NAME bash -c 'DISPLAY=:99 xdpyinfo' | grep -q 'screen #0'"
echo ""

# 6. 检查 VNC 连接
echo "6. 检查 VNC 连接"
test_service "VNC 服务可访问" "docker exec $CONTAINER_NAME bash -c 'timeout 2 nc -zv localhost 5900'"
echo ""

# 7. 检查 noVNC token 配置
echo "7. 检查 noVNC token 配置"
if docker exec "$CONTAINER_NAME" cat /etc/novnc/tokenfile | grep -q "$NOVNC_TOKEN"; then
    echo -e "${GREEN}✓ Token 配置正确${NC}"
else
    echo -e "${RED}✗ Token 配置错误${NC}"
fi
echo ""

# 8. 检查 HTTP 端点
echo "8. 检查 HTTP 端点"
test_service "bb-browser-api 健康检查" "curl -s -f http://localhost:18888/status"
test_service "noVNC Web 界面" "curl -s -f http://localhost:6080/vnc.html"
echo ""

# 9. 检查日志文件
echo "9. 检查日志文件"
echo "最近的错误日志："
docker exec "$CONTAINER_NAME" bash -c 'tail -5 /var/log/supervisor/*_err.log 2>/dev/null || echo "无错误日志"'
echo ""

# 10. 服务重启测试
echo "10. 服务重启测试"
echo -n "重启 x11vnc... "
docker exec "$CONTAINER_NAME" supervisorctl restart x11vnc > /dev/null 2>&1
sleep 2
if docker exec "$CONTAINER_NAME" supervisorctl status x11vnc | grep -q RUNNING; then
    echo -e "${GREEN}✓ 重启成功${NC}"
else
    echo -e "${RED}✗ 重启失败${NC}"
fi

echo -n "重启 websockify... "
docker exec "$CONTAINER_NAME" supervisorctl restart websockify > /dev/null 2>&1
sleep 2
if docker exec "$CONTAINER_NAME" supervisorctl status websockify | grep -q RUNNING; then
    echo -e "${GREEN}✓ 重启成功${NC}"
else
    echo -e "${RED}✗ 重启失败${NC}"
fi
echo ""

# 总结
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "访问方式："
echo "  noVNC Web: http://localhost:6080/vnc.html?token=$NOVNC_TOKEN"
echo "  VNC 直连:  localhost:5900"
echo "  API 接口:  http://localhost:18888"
echo ""
echo "管理命令："
echo "  查看状态: docker exec $CONTAINER_NAME supervisorctl status"
echo "  查看日志: docker exec $CONTAINER_NAME tail -f /var/log/supervisor/x11vnc.log"
echo "  重启服务: docker exec $CONTAINER_NAME supervisorctl restart all"
