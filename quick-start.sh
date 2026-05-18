#!/bin/bash
# 快速启动脚本

set -e

echo "=========================================="
echo "BB Browser API Server 快速启动"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 检查 Docker
echo -n "检查 Docker... "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo "✗"
    echo "错误: 未安装 Docker"
    exit 1
fi

# 2. 检查 Docker Compose
echo -n "检查 Docker Compose... "
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo "✗"
    echo "错误: 未安装 Docker Compose"
    exit 1
fi

# 3. 创建数据目录
echo -n "创建数据目录... "
mkdir -p /data/bb-browser-api/chrome-profile
echo -e "${GREEN}✓${NC}"

# 4. 检查是否已有容器运行
if docker ps -a | grep -q browser-platform; then
    echo -e "${YELLOW}检测到已存在的容器${NC}"
    read -p "是否重新构建? (y/N): " rebuild
    if [[ $rebuild =~ ^[Yy]$ ]]; then
        echo "停止并删除旧容器..."
        docker-compose down
        echo "重新构建镜像..."
        docker-compose build --no-cache
    else
        echo "使用现有容器..."
    fi
else
    echo "构建 Docker 镜像..."
    docker-compose build
fi

# 5. 启动服务
echo "启动服务..."
docker-compose up -d

# 6. 等待服务启动
echo -n "等待服务启动"
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""

# 7. 检查服务状态
echo ""
echo "检查服务状态..."
docker exec browser-platform supervisorctl status

# 8. 显示访问信息
echo ""
echo "=========================================="
echo -e "${GREEN}启动成功!${NC}"
echo "=========================================="
echo ""
echo "访问方式："
echo "  noVNC Web: http://localhost:6080/vnc.html?token=tec"
echo "  VNC 直连:  localhost:5900"
echo "  API 接口:  http://localhost:18888"
echo ""
echo "管理命令："
echo "  查看日志: docker-compose logs -f"
echo "  查看状态: docker exec browser-platform supervisorctl status"
echo "  停止服务: docker-compose down"
echo "  运行测试: ./test/test_services.sh"
echo ""
echo "故障排查："
echo "  查看文档: docs/troubleshooting.md"
echo ""

# 9. 询问是否运行测试
read -p "是否运行服务测试? (Y/n): " run_test
if [[ ! $run_test =~ ^[Nn]$ ]]; then
    echo ""
    chmod +x test/test_services.sh
    ./test/test_services.sh
fi
