#!/bin/bash
set -e

echo "[1] init display stack"
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

fluxbox &
sleep 2

x11vnc -display :99 -forever -nopw -listen 0.0.0.0 &
websockify --web=/usr/share/novnc/ 6080 localhost:5900 &

echo "[2] bb-browser-api (MASTER CONTROLLER)"

mkdir -p /data/chrome-profile

bb-browser-api daemon start  &&  bb-browser-api daemon status
echo "system ready"
wait