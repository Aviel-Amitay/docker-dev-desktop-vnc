#!/usr/bin/env bash
set -e

# 🔑 KEY CHANGE: configurable via docker-compose env
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
DISPLAY_NUM="${DISPLAY_NUM:-1}"
RESOLUTION="${RESOLUTION:-1920x1080}"
DEPTH="${DEPTH:-16}"

export USER=dev
export HOME=/home/dev
cd "$HOME"

# Create VNC password file
mkdir -p "$HOME/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

# Clean any stale VNC stuff
rm -f /tmp/.X${DISPLAY_NUM}-lock || true
rm -f /tmp/.X11-unix/X${DISPLAY_NUM} || true

echo "Starting VNC server on :${DISPLAY_NUM} (${RESOLUTION}, depth ${DEPTH})"

tigervncserver :${DISPLAY_NUM} \
  -geometry "${RESOLUTION}" \
  -depth "${DEPTH}" \
  -localhost no

# Tail logs so container stays alive
tail -F "$HOME/.vnc"/*:*.log
