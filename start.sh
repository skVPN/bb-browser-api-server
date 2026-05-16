#!/bin/bash
set -e

echo "[1] init display stack"
## Ensure display :99 is available and avoid duplicate Xvfb starts
if pgrep -f "Xvfb .*:99" >/dev/null 2>&1; then
	echo "Xvfb already running for display :99"
else
	if [ -e /tmp/.X99-lock ]; then
		echo "Found stale /tmp/.X99-lock — removing"
		rm -f /tmp/.X99-lock || true
	fi
	Xvfb :99 -screen 0 1920x1080x24 &
	# give Xvfb a moment to initialize
	sleep 1
fi
export DISPLAY=:99

fluxbox &
sleep 2

x11vnc -display :99 -forever -nopw -listen 0.0.0.0 &

NOVNC_TOKEN="${NOVNC_TOKEN:-tec}"
mkdir -p /root/.novnc
cat >/root/.novnc/tokenfile <<EOF
${NOVNC_TOKEN}: localhost:5900
EOF
cat >/usr/share/novnc/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0;url=vnc.html?token=${NOVNC_TOKEN}" />
  <title>Redirecting to noVNC</title>
</head>
<body>
  <p>Redirecting to <a href="vnc.html?token=${NOVNC_TOKEN}">vnc.html?token=${NOVNC_TOKEN}</a></p>
</body>
</html>
EOF
websockify --web=/usr/share/novnc/ \
  --token-plugin TokenFile \
  --token-source /root/.novnc/tokenfile \
  6080 localhost:5900 &

echo "[2] bb-browser-api (MASTER CONTROLLER)"

if [ -d /root/.bb-browser/browser/user-data ]; then
	rm -f /root/.bb-browser/browser/user-data/Singleton* || true
fi

bb-browser-api daemon start  &&  bb-browser-api daemon status
echo "system ready"
wait