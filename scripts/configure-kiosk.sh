#!/usr/bin/env bash
# Configura apenas o Chromium e o ponteiro das telas de exibição.
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
APP_DIR="/opt/viewcpjc"
apt-get install -y --no-install-recommends unclutter-xfixes
install -d -m 0755 /etc/chromium/policies/managed
install -m 0644 "$APP_DIR/deploy/chromium-policy.json" /etc/chromium/policies/managed/viewcpjc.json
echo "Política de tradução e ocultação do ponteiro configuradas. Reinicie viewcpjc-display para aplicar."
