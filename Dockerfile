FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

# 一次性安装所有系统依赖和字体
RUN apt-get update && apt-get install -y \
    # 基础工具
    wget curl gnupg ca-certificates \
    # X11 和 VNC 相关
    xvfb fluxbox x11vnc novnc websockify \
    dbus-x11 \
    # Chrome 依赖
    libnss3 libxss1 libasound2 libgbm1 libgtk-3-0 fonts-liberation \
    # 进程管理
    supervisor \
    # 中文字体支持
    fonts-wqy-zenhei fonts-wqy-microhei \
    fonts-noto-cjk fonts-noto-cjk-extra \
    fonts-arphic-ukai fonts-arphic-uming \
    # 中文语言包
    locales language-pack-zh-hans \
    # 字体配置工具
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# 配置中文 locale
RUN locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# 设置环境变量
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh

# 安装 Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && \
    apt-get install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# 安装 Node.js 和 bb-browser-api
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g bb-browser-api@0.12.9 && \
    rm -rf /var/lib/apt/lists/*

# Patch noVNC ui.js: force path to include token from URL at connect time
RUN sed -i "s|var path = UI.getSetting('path');|var path = UI.getSetting('path'); var _urlToken = (new URLSearchParams(window.location.search)).get('token'); if (_urlToken) { path = 'websockify?token=' + encodeURIComponent(_urlToken); }|" /usr/share/novnc/app/ui.js

# 复制字体配置
COPY fonts.conf /etc/fonts/local.conf

# 更新字体缓存
RUN fc-cache -fv

# 配置 supervisord
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]