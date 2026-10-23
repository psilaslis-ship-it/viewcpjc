#!/usr/bin/env bash
# Executado pelo serviço viewcpjc-display. Ajuste /etc/viewcpjc/display.conf.
set -euo pipefail
BASE_URL="http://127.0.0.1:8080"
source /etc/viewcpjc/display.conf

# Aguarda o painel estar pronto após boot/reinício.
until curl --silent --fail "$BASE_URL/api/state" >/dev/null; do sleep 1; done

# O kernel pode expor HDMI-A-1, enquanto Xorg o chama HDMI-1. Resolve ambos os casos.
resolve_x_output() {
  local wanted="$1" prefix="${1%%-*}" candidate require_connected="${2:-yes}"
  candidate=$(xrandr --query | awk -v output="$wanted" -v connected="$require_connected" '$1 == output && (connected == "no" || $2 == "connected") {print $1; exit}')
  if [[ -z "$candidate" ]]; then
    candidate=$(xrandr --query | awk -v type="$prefix" '$1 ~ ("^" type "-") && $2 == "connected" {print $1; exit}')
  fi
  if [[ -z "$candidate" && "$require_connected" == "no" ]]; then
    candidate=$(xrandr --query | awk -v type="$prefix" '$1 ~ ("^" type "-") {print $1; exit}')
  fi
  [[ -n "$candidate" ]] || { echo "Saída Xorg não encontrada para: $wanted" >&2; return 1; }
  printf '%s\n' "$candidate"
}
VGA_OUTPUT=$(resolve_x_output "$VGA_OUTPUT")
HDMI_OUTPUT=$(resolve_x_output "$HDMI_OUTPUT" no) || HDMI_OUTPUT=""
echo "Saídas Xorg em uso: HDMI=$HDMI_OUTPUT; VGA=$VGA_OUTPUT"

xrandr --output "$VGA_OUTPUT" --auto --primary --pos 0x0

geometry_for() {
  xrandr --query | sed -nE "/^$1 connected/ s/.* ([0-9]+x[0-9]+\+[0-9]+\+[0-9]+).*/\1/p" | head -n1
}
vga_geometry=$(geometry_for "$VGA_OUTPUT")
[[ -n "$vga_geometry" ]] || { echo "Não foi possível determinar a tela VGA em xrandr." >&2; exit 1; }
launch() {
  local page="$1" geometry="$2" profile="$3"
  local size="${geometry%%+*}" coords="${geometry#*+}"
  local x="${coords%%+*}" y="${coords#*+}"
  local width="${size%x*}" height="${size#*x}"
  chromium --app="$BASE_URL/$page" --user-data-dir="$profile" --window-position="$x,$y" --window-size="$width,$height" --autoplay-policy=no-user-gesture-required --no-first-run --disable-session-crashed-bubble &
}
# --app oculta a navegação, mas não remove a moldura do gerenciador de janelas.
# Aguarda cada janela existir e solicita fullscreen separadamente ao Openbox.
fullscreen_window() {
  local title="$1" attempt
  for ((attempt=0; attempt<60; attempt++)); do
    if wmctrl -l | grep -Fq "$title"; then
      wmctrl -r "$title" -b add,fullscreen
      echo "Tela cheia ativada: $title"
      return 0
    fi
    sleep 0.5
  done
  echo "Janela não encontrada para tela cheia: $title" >&2
  return 1
}

# A VGA não depende de cabo, TV ou duplicador HDMI. Mantém o Xorg vivo e
# aguarda a conexão HDMI sem reiniciar o contador.
launch clock.html "$vga_geometry" /var/lib/viewcpjc/chromium-vga
fullscreen_window "Contador VGA" || true
hdmi_started=no
while true; do
  if [[ -n "$HDMI_OUTPUT" ]] && xrandr --query | awk -v output="$HDMI_OUTPUT" '$1 == output && $2 == "connected" {found=1} END {exit !found}'; then
    if [[ "$hdmi_started" == no ]]; then
      if xrandr --output "$HDMI_OUTPUT" --auto --right-of "$VGA_OUTPUT"; then
        hdmi_geometry=$(geometry_for "$HDMI_OUTPUT")
        if [[ -n "$hdmi_geometry" ]]; then
          launch hdmi.html "$hdmi_geometry" /var/lib/viewcpjc/chromium-hdmi
          fullscreen_window "Player HDMI" || true
          hdmi_started=yes
        fi
      fi
    fi
  fi
  sleep 2
done
