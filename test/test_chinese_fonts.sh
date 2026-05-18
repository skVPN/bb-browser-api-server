#!/bin/bash
# 中文字体测试脚本

CONTAINER_NAME="browser-platform"

echo "=========================================="
echo "中文字体支持测试"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 检查 locale 配置
echo "1. 检查 locale 配置"
docker exec "$CONTAINER_NAME" locale | grep -E "LANG|LC_ALL"
echo ""

# 2. 检查已安装的中文字体
echo "2. 检查已安装的中文字体"
echo "文泉驿字体："
docker exec "$CONTAINER_NAME" fc-list | grep -i "WenQuanYi" | wc -l
echo "Noto CJK 字体："
docker exec "$CONTAINER_NAME" fc-list | grep -i "Noto.*CJK" | wc -l
echo "文鼎字体："
docker exec "$CONTAINER_NAME" fc-list | grep -i "AR PL" | wc -l
echo ""

# 3. 列出所有中文字体
echo "3. 已安装的中文字体列表："
docker exec "$CONTAINER_NAME" fc-list :lang=zh | head -20
echo ""

# 4. 检查字体配置
echo "4. 检查字体配置文件"
if docker exec "$CONTAINER_NAME" test -f /etc/fonts/local.conf; then
    echo -e "${GREEN}✓ 字体配置文件存在${NC}"
else
    echo -e "${RED}✗ 字体配置文件不存在${NC}"
fi
echo ""

# 5. 测试字体渲染
echo "5. 测试字体渲染"
docker exec "$CONTAINER_NAME" bash -c 'fc-match "sans-serif"'
docker exec "$CONTAINER_NAME" bash -c 'fc-match "serif"'
docker exec "$CONTAINER_NAME" bash -c 'fc-match "monospace"'
echo ""

# 6. 检查环境变量
echo "6. 检查环境变量"
docker exec "$CONTAINER_NAME" bash -c 'echo "LANG=$LANG"'
docker exec "$CONTAINER_NAME" bash -c 'echo "LC_ALL=$LC_ALL"'
docker exec "$CONTAINER_NAME" bash -c 'echo "LANGUAGE=$LANGUAGE"'
echo ""

# 7. 建议
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "如果中文仍然显示为方框："
echo "1. 重新构建镜像: docker-compose build --no-cache"
echo "2. 重启容器: docker-compose up -d"
echo "3. 清除浏览器缓存"
echo "4. 在 Chrome 中访问 chrome://settings/fonts 检查字体设置"
echo ""
echo "推荐的中文字体："
echo "  - 标准字体: Noto Sans CJK SC"
echo "  - 衬线字体: Noto Serif CJK SC"
echo "  - 等宽字体: Noto Sans Mono CJK SC"
