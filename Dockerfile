FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

RUN apt-get update && apt-get install -y \
    xvfb fluxbox x11vnc novnc websockify \
    wget curl gnupg ca-certificates \
    dbus-x11 fonts-liberation \
    libnss3 libxss1 libasound2 \
    libgbm1 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && apt-get install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb

# Node + bb-browser-api
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g bb-browser-api@0.12.9

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]