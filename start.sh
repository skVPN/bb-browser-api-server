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

# Simple watchdog: start and restart x11vnc and websockify when they die
start_x11vnc() {
	echo "[watchdog] starting x11vnc"
	/usr/bin/x11vnc -display :99 -forever -nopw -listen 0.0.0.0 >/tmp/x11vnc.log 2>&1 &
	X11VNC_PID=$!
}

wait_for_5900() {
	local tries=0
	while ! (echo > /dev/tcp/127.0.0.1/5900) >/dev/null 2>&1; do
		tries=$((tries+1))
		if [ "$tries" -ge 30 ]; then
			echo "[watchdog] timeout waiting for 127.0.0.1:5900"
			return 1
		fi
		sleep 1
	done
	return 0
}

start_websockify() {
	echo "[watchdog] starting websockify"
	/usr/bin/websockify --web=/usr/share/novnc/ \
		--token-plugin TokenFile \
		--token-source /root/.novnc/tokenfile \
		6080 localhost:5900 >/tmp/websockify.log 2>&1 &
	WEBSOCKIFY_PID=$!
}

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

# initial start
start_x11vnc
if wait_for_5900; then
	start_websockify
else
	echo "[watchdog] VNC not ready yet; websockify will start when available"
fi

# handle termination: kill children and exit
_shutdown() {
	echo "[watchdog] shutting down"
	kill ${WEBSOCKIFY_PID:-0} ${X11VNC_PID:-0} 2>/dev/null || true
	exit 0
}
trap _shutdown SIGINT SIGTERM

# watchdog loop runs in background; main script continues
(
	while true; do
		if [ -z "${X11VNC_PID:-}" ] || ! kill -0 "$X11VNC_PID" 2>/dev/null; then
			echo "[watchdog] x11vnc not running, restarting"
			start_x11vnc
		fi

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