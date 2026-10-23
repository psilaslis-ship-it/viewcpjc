#!/usr/bin/env bash
set -Eeuo pipefail
export DISPLAY=:0
export HOME=/var/lib/display
xset -dpms
xset s off
xset s noblank
openbox &
if command -v unclutter-xfixes >/dev/null 2>&1; then
  unclutter-xfixes --start-hidden --timeout 1 &
fi
exec /opt/viewcpjc/deploy/start-displays.sh
