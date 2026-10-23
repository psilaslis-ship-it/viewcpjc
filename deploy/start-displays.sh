#!/usr/bin/env bash
# Executado pelo serviço viewcpjc-display. Ajuste /etc/viewcpjc/display.conf.
set -euo pipefail
BASE_URL="http://127.0.0.1:8080"
source /etc/viewcpjc/display.conf

# Aguarda o painel estar pronto após boot/reinício.
until curl --silent --fail "$BASE_URL/api/state" >/dev/null; do sleep 1; done

# O kernel pode expor HDMI-A-1, enquanto Xorg o chama HDMI-1. Resolve ambos os casos.
resolve_x_output() {
  local wanted="$1" prefix="${1%%-*}" candidate
  candidate=$(xrandr --query | awk -v output="$wanted" '$1 == output {print $1; exit}')
  if [[ -z "$candidate" ]]; then
    candidate=$(xrandr --query | awk -v type="$prefix" '$1 ~ ("^" type "-") && $2 == "connected" {print $1; exit}')
  fi
  [[ -n "$candidate" ]] || { echo "Saída Xorg não encontrada para: $wanted" >&2; return 1; }
  printf '%s\n' "$candidate"
}
HDMI_OUTPUT=$(resolve_x_output "$HDMI_OUTPUT")
VGA_OUTPUT=$(resolve_x_output "$VGA_OUTPUT")
echo "Saídas Xorg em uso: HDMI=$HDMI_OUTPUT; VGA=$VGA_OUTPUT"

xrandr --output "$HDMI_OUTPUT" --auto
xrandr --output "$VGA_OUTPUT" --auto --left-of "$HDMI_OUTPUT"

geometry_for() {
  xrandr --query | sed -nE "/^$1 connected/ s/.* ([0-9]+x[0-9]+\+[0-9]+\+[0-9]+).*/\1/p" | head -n1
}
vga_geometry=$(geometry_for "$VGA_OUTPUT")
hdmi_geometry=$(geometry_for "$HDMI_OUTPUT")
[[ -n "$vga_geometry" && -n "$hdmi_geometry" ]] || { echo "Não foi possível determinar as telas em xrandr." >&2; exit 1; }
launch() {
  local page="$1" geometry="$2" profile="$3"
  local size="${geometry%%+*}" coords="${geometry#*+}" x="${coords%%+*}" y="${coords#*+}"
  local width="${size%x*}" height="${size#*x}"
  chromium --app="$BASE_URL/$page" --user-data-dir="$profile" --window-position="$x,$y" --window-size="$width,$height" --autoplay-policy=no-user-gesture-required --no-first-run --disable-session-crashed-bubble &
}
launch clock.html "$vga_geometry" /var/lib/viewcpjc/chromium-vga
launch hdmi.html "$hdmi_geometry" /var/lib/viewcpjc/chromium-hdmi
wait

# Cada janela é um processo Chromium distinto. O conteúdo e a conexão Socket.IO são independentes.
chromium --kiosk --app="$BASE_URL/clock.html" --class=VgaClock --start-fullscreen &
sleep 1
chromium --kiosk --app="$BASE_URL/hdmi.html" --class=HdmiPlayer --start-fullscreen &

# Posicionamento explícito por saída: pode ser personalizado em um WM leve (openbox/i3).
# Para validar nomes/posições: DISPLAY=:0 xrandr --query
