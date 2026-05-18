# 中文字体支持指南

## 问题描述

在 Docker 容器中运行的 Chrome 浏览器显示中文时出现乱码或方框。

## 原因分析

### 1. 缺少中文字体
Ubuntu 基础镜像默认不包含中文字体，导致浏览器无法正确渲染中文字符。

### 2. 缺少语言包
没有安装中文 locale，系统无法正确处理中文字符编码。

### 3. 字体配置不正确
Chrome 需要正确的字体配置才能选择合适的中文字体。

## 解决方案

### 已实施的改进

我们在 Dockerfile 中添加了以下内容：

#### 1. 安装中文字体

```dockerfile
# 中文字体支持
fonts-wqy-zenhei fonts-wqy-microhei      # 文泉驿字体
fonts-noto-cjk fonts-noto-cjk-extra      # Google Noto CJK 字体
fonts-arphic-ukai fonts-arphic-uming     # 文鼎字体
```

**字体说明**：
- **文泉驿正黑/微米黑**：开源中文字体，显示效果好
- **Noto Sans/Serif CJK**：Google 开发的高质量 CJK 字体
- **文鼎 UKai/UMing**：传统的中文字体

#### 2. 安装语言包

```dockerfile
# 中文语言包
locales language-pack-zh-hans

# 配置中文 locale
RUN locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
```

#### 3. 设置环境变量

```dockerfile
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh
```

#### 4. 字体配置文件

创建了 `fonts.conf` 文件，配置字体优先级和渲染选项。

## 部署步骤

### 1. 重新构建镜像

```bash
# 停止容器
docker-compose down

# 重新构建（不使用缓存）
docker-compose build --no-cache

# 启动容器
docker-compose up -d
```

### 2. 验证字体安装

```bash
# 运行字体测试脚本
chmod +x test/test_chinese_fonts.sh
./test/test_chinese_fonts.sh
```

### 3. 测试中文显示

访问以下网站测试中文显示：
- https://www.baidu.com
- https://www.zhihu.com
- https://www.bilibili.com

## 验证步骤

### 1. 检查 locale

```bash
docker exec browser-platform locale
```

期望输出：
```
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
```

### 2. 检查已安装的字体

```bash
# 列出所有中文字体
docker exec browser-platform fc-list :lang=zh

# 检查特定字体
docker exec browser-platform fc-list | grep -i "WenQuanYi"
docker exec browser-platform fc-list | grep -i "Noto.*CJK"
```

### 3. 检查字体匹配

```bash
# 检查默认字体
docker exec browser-platform fc-match "sans-serif"
docker exec browser-platform fc-match "serif"
docker exec browser-platform fc-match "monospace"
```

期望输出包含中文字体名称，如：
```
NotoSansCJK-Regular.ttc: "Noto Sans CJK SC" "Regular"
```

### 4. 在浏览器中检查

1. 访问 `chrome://settings/fonts`
2. 检查字体设置：
   - 标准字体：Noto Sans CJK SC
   - 衬线字体：Noto Serif CJK SC
   - 等宽字体：Noto Sans Mono CJK SC

## 故障排查

### 问题 1：中文仍然显示为方框

**可能原因**：
- 镜像未重新构建
- 字体缓存未更新
- 浏览器缓存问题

**解决方案**：

```bash
# 1. 完全重新构建
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 2. 进入容器更新字体缓存
docker exec browser-platform fc-cache -fv

# 3. 重启浏览器 API
docker exec browser-platform supervisorctl restart bb-browser-api

# 4. 清除浏览器数据
docker exec browser-platform bash -c 'rm -rf /root/.bb-browser/browser/user-data/Default/Cache/*'
```

### 问题 2：部分中文显示正常，部分显示为方框

**可能原因**：
- 字体不完整
- 缺少某些字符集

**解决方案**：

```bash
# 安装更多字体
docker exec browser-platform apt-get update
docker exec browser-platform apt-get install -y fonts-noto-cjk-extra

# 更新字体缓存
docker exec browser-platform fc-cache -fv
```

### 问题 3：字体显示模糊或锯齿

**可能原因**：
- 字体渲染配置不正确
- 分辨率设置问题

**解决方案**：

1. 检查字体配置文件 `/etc/fonts/local.conf`
2. 调整 Xvfb 分辨率（在 `supervisord.conf` 中）
3. 启用字体抗锯齿

### 问题 4：环境变量未生效

**检查步骤**：

```bash
# 检查容器环境变量
docker exec browser-platform env | grep -E "LANG|LC_ALL"

# 检查 supervisord 进程环境变量
docker exec browser-platform bash -c 'cat /proc/$(pgrep bb-browser-api)/environ | tr "\0" "\n" | grep LANG'
```

**解决方案**：

确保 `supervisord.conf` 中的 environment 配置正确：
```ini
environment=DISPLAY=":99",LANG="zh_CN.UTF-8",LC_ALL="zh_CN.UTF-8"
```

## 手动安装字体（高级）

如果需要安装特定字体：

### 1. 下载字体文件

```bash
# 进入容器
docker exec -it browser-platform bash

# 创建字体目录
mkdir -p /usr/share/fonts/custom

# 下载字体（示例）
cd /usr/share/fonts/custom
wget https://example.com/your-font.ttf
```

### 2. 更新字体缓存

```bash
fc-cache -fv
```

### 3. 验证字体

```bash
fc-list | grep "your-font"
```

## Chrome 字体设置

### 通过 API 设置字体

如果 bb-browser-api 支持，可以通过 API 设置字体：

```javascript
// 示例：设置 Chrome 字体
{
  "preferences": {
    "webkit": {
      "webprefs": {
        "fonts": {
          "standard": {
            "Zyyy": "Noto Sans CJK SC"
          },
          "serif": {
            "Zyyy": "Noto Serif CJK SC"
          },
          "sansserif": {
            "Zyyy": "Noto Sans CJK SC"
          },
          "fixed": {
            "Zyyy": "Noto Sans Mono CJK SC"
          }
        }
      }
    }
  }
}
```

### 通过 Chrome Preferences 文件

```bash
# 编辑 Chrome 配置文件
docker exec browser-platform bash -c 'cat > /root/.bb-browser/browser/user-data/Default/Preferences << EOF
{
  "webkit": {
    "webprefs": {
      "fonts": {
        "standard": {
          "Zyyy": "Noto Sans CJK SC"
        }
      }
    }
  }
}
EOF'
```

## 推荐字体

### 1. Noto Sans CJK SC（推荐）

**优点**：
- Google 开发，质量高
- 覆盖字符全
- 显示效果好
- 支持多种字重

**用途**：
- 网页正文
- UI 界面
- 通用显示

### 2. 文泉驿正黑/微米黑

**优点**：
- 开源免费
- 显示清晰
- 文件较小

**用途**：
- 系统界面
- 终端显示
- 备用字体

### 3. 文鼎 UKai/UMing

**优点**：
- 传统字体
- 适合正式文档

**用途**：
- 文档阅读
- 打印输出

## 字体大小对比

| 字体包 | 大小 | 字符数 |
|--------|------|--------|
| fonts-wqy-zenhei | ~10MB | ~35,000 |
| fonts-wqy-microhei | ~5MB | ~35,000 |
| fonts-noto-cjk | ~120MB | ~65,000 |
| fonts-noto-cjk-extra | ~150MB | ~65,000+ |
| fonts-arphic-ukai | ~10MB | ~30,000 |

## 性能考虑

### 镜像大小

添加中文字体后，镜像大小会增加约 150-200MB。

**优化建议**：
- 只安装必需的字体
- 使用压缩的字体格式
- 考虑使用多阶段构建

### 字体加载时间

首次加载字体可能需要几秒钟。

**优化建议**：
- 预加载常用字体
- 使用字体缓存
- 优化字体配置

## 测试清单

- [ ] 运行字体测试脚本
- [ ] 检查 locale 配置
- [ ] 验证字体安装
- [ ] 测试百度首页
- [ ] 测试知乎页面
- [ ] 测试 B 站页面
- [ ] 检查 Chrome 字体设置
- [ ] 测试不同字重
- [ ] 测试繁体中文
- [ ] 测试日文/韩文

## 常见问题

### Q: 为什么安装了字体还是乱码？

A: 可能原因：
1. 镜像未重新构建
2. 环境变量未生效
3. 浏览器缓存问题
4. 字体缓存未更新

### Q: 如何选择合适的字体？

A: 推荐使用 Noto Sans CJK SC，它是 Google 开发的高质量字体，覆盖字符全，显示效果好。

### Q: 字体文件太大怎么办？

A: 可以只安装 fonts-wqy-zenhei 和 fonts-wqy-microhei，它们文件较小但显示效果也不错。

### Q: 如何测试字体是否正常？

A: 运行 `./test/test_chinese_fonts.sh` 脚本，然后访问中文网站测试。

## 参考资源

- [Noto CJK 字体](https://github.com/googlefonts/noto-cjk)
- [文泉驿字体](http://wenq.org/)
- [Fontconfig 配置](https://www.freedesktop.org/wiki/Software/fontconfig/)
- [Chrome 字体设置](https://support.google.com/chrome/answer/96810)

## 总结

通过安装中文字体、配置 locale 和优化字体配置，可以完美解决 Docker 容器中 Chrome 浏览器的中文显示问题。记得重新构建镜像并清除浏览器缓存。
