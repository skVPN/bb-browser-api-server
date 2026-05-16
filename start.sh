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

# Function to start x11vnc and record PID
start_x11vnc() {
    echo "[watchdog] starting x11vnc"
    x11vnc -display :99 -forever -nopw -listen 0.0.0.0 >/var/log/x11vnc.log 2>&1 &
    X11VNC_PID=$!
}

# Wait until 127.0.0.1:5900 is accepting TCP connections (timeout after tries)
wait_for_5900() {
    local tries=0
    while ! (echo > /dev/tcp/127.0.0.1/5900) >/dev/null 2>&1; do
        tries=$((tries+1))
        if [ "$tries" -ge 30 ]; then
            return 1
        fi
        sleep 1
    done
    return 0
}

# Start websockify using a token-config file
start_websockify() {
    echo "[watchdog] starting websockify"
    # kill any stale instances
    pkill -f "websockify .*6080" || true
    sleep 1
    # use --target-config which reads lines like 'token: host:port'
    websockify --web=/usr/share/novnc --target-config /root/.novnc/tokenfile 6080 --daemon || true
    # try to capture its PID
    WEBSOCKIFY_PID=$(pgrep -f "websockify .*6080" | head -n1 || true)
}

# prepare token (use NOVNC_TOKEN env, default to 'tec')
NOVNC_TOKEN="${NOVNC_TOKEN:-tec}"
mkdir -p /root/.novnc
cat >/root/.novnc/tokenfile <<EOF
${NOVNC_TOKEN}: localhost:5900
EOF

# create a small redirect index so root hits the vnc page with token
cat >/usr/share/novnc/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0;url=vnc.html?token=${NOVNC_TOKEN}" />
  <title>Redirecting to noVNC</title>
</head>
<body>
  <p>Redirecting to <a href="vnc_auth.html?token=${NOVNC_TOKEN}x">vnc_auth.html?token=${NOVNC_TOKEN}</a></p>
</body>
</html>
EOF

echo "[watchdog] supervisor starting"

# initial start
start_x11vnc

# supervisor loop (background)
(
    while true; do
        # ensure x11vnc
        if [ -z "${X11VNC_PID:-}" ] || ! kill -0 "$X11VNC_PID" 2>/dev/null; then
            echo "[watchdog] x11vnc not running, restarting"
            start_x11vnc
        fi

        # ensure websockify (only start when VNC ready)
        if [ -z "${WEBSOCKIFY_PID:-}" ] || ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then
            echo "[watchdog] websockify not running, attempting to start (wait for VNC)"
            if wait_for_5900; then
                start_websockify
            else
                echo "[watchdog] still no VNC on 5900; will retry"
            fi
        fi

        sleep 5
    done
) &

echo "[2] bb-browser-api (MASTER CONTROLLER)"

if [ -d /root/.bb-browser/browser/user-data ]; then
    rm -f /root/.bb-browser/browser/user-data/Singleton* || true
fi

bb-browser-api daemon start  &&  bb-browser-api daemon status
echo "system ready"
wait
