#!/usr/bin/env bash
# 此脚本已被 supervisord 替代，保留用于手动调试

set -e

export DISPLAY=:99
if [ -d /root/.bb-browser/browser/user-data ]; then
    rm -f /root/.bb-browser/browser/user-data/Singleton* || true
fi

echo "[1] Xvfb"
Xvfb :99 -screen 0 1920x1080x24 &

sleep 2

echo "[2] fluxbox"
fluxbox &

sleep 2

echo "[3] x11vnc"
x11vnc \
  -display :99 \
  -forever \
  -shared \
  -nopw \
  -rfbport 5900 \
  -listen 0.0.0.0 &

sleep 2

echo "[4] websockify / noVNC"
mkdir -p /etc/novnc
# token 从环境变量读取，默认 'tec'
NOVNC_TOKEN="${NOVNC_TOKEN:-tec}"
echo "${NOVNC_TOKEN}: localhost:5900" > /etc/novnc/tokenfile
websockify \
  --web=/usr/share/novnc \
  --token-plugin=TokenFile \
  --token-source=/etc/novnc/tokenfile \
  6080 &

sleep 2

echo "[5] bb-browser-api"
# 如果你的服务需要 DISPLAY
DISPLAY=:99 bb-browser-api daemon start &

echo "All services started"
bb-browser-api daemon status
tail -f /dev/null
