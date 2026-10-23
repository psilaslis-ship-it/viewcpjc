#!/usr/bin/env bash
# Atualiza somente o código. Configuração, mídia e estado permanecem em /var/lib e /etc.
set -Eeuo pipefail
APP_DIR="/opt/viewcpjc"
BRANCH="main"
[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }
[[ -d "$APP_DIR/.git" ]] || { echo "Aplicação não instalada em $APP_DIR. Execute install.sh primeiro." >&2; exit 1; }

systemctl stop viewcpjc-display.service viewcpjc.service
git -C "$APP_DIR" fetch --prune origin
git -C "$APP_DIR" checkout --force "origin/$BRANCH"
cd "$APP_DIR"
npm ci --omit=dev
chmod 0755 scripts/install.sh scripts/update.sh deploy/xinitrc deploy/display-session.sh deploy/start-displays.sh
install -m 0644 deploy/viewcpjc.service /etc/systemd/system/viewcpjc.service
install -m 0644 deploy/viewcpjc-display.service /etc/systemd/system/viewcpjc-display.service
systemctl daemon-reload
systemctl start viewcpjc.service viewcpjc-display.service
systemctl --no-pager --full status viewcpjc.service viewcpjc-display.service
