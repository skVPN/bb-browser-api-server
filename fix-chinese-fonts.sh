#!/bin/bash
# 快速修复中文字体问题

set -e

echo "=========================================="
echo "修复中文字体显示问题"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}此脚本将：${NC}"
echo "1. 停止当前容器"
echo "2. 重新构建镜像（包含中文字体）"
echo "3. 启动新容器"
echo "4. 验证字体安装"
echo ""

read -p "是否继续? (Y/n): " confirm
if [[ $confirm =~ ^[Nn]$ ]]; then
    echo "已取消"
    exit 0
fi

echo ""
echo "步骤 1/4: 停止容器..."
docker-compose down

echo ""
echo "步骤 2/4: 重新构建镜像（这可能需要几分钟）..."
docker-compose build --no-cache

echo ""
echo "步骤 3/4: 启动容器..."
docker-compose up -d

echo ""
echo -n "等待容器启动"
for i in {1..15}; do
    echo -n "."
    sleep 1
done
echo ""

echo ""
echo "步骤 4/4: 验证字体安装..."
sleep 2

# 检查 locale
echo ""
echo "Locale 配置:"
docker exec browser-platform locale | grep -E "LANG|LC_ALL"

# 检查字体
echo ""
echo "已安装的中文字体:"
echo -n "文泉驿字体: "
docker exec browser-platform fc-list | grep -i "WenQuanYi" | wc -l
echo -n "Noto CJK 字体: "
docker exec browser-platform fc-list | grep -i "Noto.*CJK" | wc -l
echo -n "文鼎字体: "
docker exec browser-platform fc-list | grep -i "AR PL" | wc -l

echo ""
echo "=========================================="
echo -e "${GREEN}修复完成！${NC}"
echo "=========================================="
echo ""
echo "下一步："
echo "1. 访问 http://localhost:6080/vnc.html?token=tec"
echo "2. 打开浏览器访问中文网站（如 baidu.com）"
echo "3. 如果还有问题，运行: ./test/test_chinese_fonts.sh"
echo "4. 查看详细文档: docs/chinese-fonts-guide.md"
echo ""
echo "提示："
echo "- 如果中文仍然显示为方框，尝试清除浏览器缓存"
echo "- 在 Chrome 中访问 chrome://settings/fonts 检查字体设置"
echo "- 推荐字体: Noto Sans CJK SC"
