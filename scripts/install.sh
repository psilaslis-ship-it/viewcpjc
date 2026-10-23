#!/usr/bin/env bash
# Instala ou repara o appliance ViewCPJC em Debian 13 (sem desktop completo).
set -Eeuo pipefail

REPO_URL="https://github.com/psilaslis-ship-it/viewcpjc.git"
BRANCH="main"
APP_DIR="/opt/viewcpjc"
DATA_DIR="/var/lib/viewcpjc"
ETC_DIR="/etc/viewcpjc"
SERVICE_USER="display"

while (($#)); do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "Uso: $0 [--repo URL] [--branch NOME]" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends git curl nodejs npm chromium xserver-xorg xserver-xorg-legacy xinit openbox dbus-x11 fonts-dseg ca-certificates

if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "/var/lib/$SERVICE_USER" --groups video,render "$SERVICE_USER"
fi
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "/var/lib/$SERVICE_USER"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "$DATA_DIR" "$DATA_DIR/uploads" "$DATA_DIR/chromium-vga" "$DATA_DIR/chromium-hdmi"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "/var/lib/$SERVICE_USER/.cache" "/var/lib/$SERVICE_USER/.cache/openbox"
install -d -m 0755 "$ETC_DIR"

if [[ -d "$APP_DIR/.git" ]]; then
  git -C "$APP_DIR" fetch --prune origin
  git -C "$APP_DIR" checkout --force "origin/$BRANCH"
else
  rm -rf "$APP_DIR"
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$APP_DIR"
fi
chown -R root:root "$APP_DIR"
chmod 0755 "$APP_DIR/scripts/install.sh" "$APP_DIR/scripts/update.sh" "$APP_DIR/deploy/xinitrc" "$APP_DIR/deploy/display-session.sh" "$APP_DIR/deploy/start-displays.sh"

cd "$APP_DIR"
npm ci --omit=dev

if [[ ! -f "$DATA_DIR/config.json" ]]; then
  install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0640 config/default.json "$DATA_DIR/config.json"
fi
if [[ ! -f "$ETC_DIR/display.conf" ]]; then
  # Descobre nomes DRM reais (por exemplo, HDMI-A-1 e VGA-1) antes do primeiro boot.
  hdmi_detected=""
  vga_detected=""
  for status_file in /sys/class/drm/*/status; do
    [[ $(cat "$status_file") == "connected" ]] || continue
    connector=$(basename "$(dirname "$status_file")")
    [[ $connector == *HDMI* ]] && hdmi_detected=${connector#*-}
    [[ $connector == *VGA* ]] && vga_detected=${connector#*-}
  done
  if [[ -n "$hdmi_detected" && -n "$vga_detected" ]]; then
    printf 'HDMI_OUTPUT="%s"\nVGA_OUTPUT="%s"\n' "$hdmi_detected" "$vga_detected" > "$ETC_DIR/display.conf"
    echo "Saídas detectadas: HDMI=$hdmi_detected, VGA=$vga_detected"
  else
    install -m 0644 deploy/display.conf.example "$ETC_DIR/display.conf"
    echo "Não foi possível detectar HDMI e VGA conectados; ajuste $ETC_DIR/display.conf depois da instalação."
  fi
fi

# Permite ao serviço iniciar o Xorg sem sessão gráfica interativa.
printf 'allowed_users=anybody\nneeds_root_rights=auto\n' > /etc/X11/Xwrapper.config
install -m 0644 deploy/viewcpjc.service /etc/systemd/system/viewcpjc.service
install -m 0644 deploy/viewcpjc-display.service /etc/systemd/system/viewcpjc-display.service
systemctl daemon-reload
systemctl enable --now viewcpjc.service viewcpjc-display.service

IP=$(hostname -I | awk '{print $1}')
echo
echo "Instalação concluída. Painel: http://${IP:-IP-DA-MAQUINA}:8080/admin.html"
echo "Antes de usar em produção, confira e ajuste: $ETC_DIR/display.conf"
