#!/usr/bin/env bash
set -Eeuo pipefail
export DISPLAY=:0
export HOME=/var/lib/display
xset -dpms
xset s off
xset s noblank
openbox &
exec /opt/viewcpjc/deploy/start-displays.sh
