#!/usr/bin/env bash
# Executado pelo serviço viewcpjc-display. Ajuste /etc/viewcpjc/display.conf.
set -euo pipefail
BASE_URL="http://127.0.0.1:8080"
source /etc/viewcpjc/display.conf

# Aguarda o painel estar pronto após boot/reinício.
until curl --silent --fail "$BASE_URL/api/state" >/dev/null; do sleep 1; done

# O kernel pode expor nomes diferentes dos usados pelo Xorg.
resolve_x_output() {
  local wanted="$1" prefix="${1%%-*}" candidate
  candidate=$(xrandr --query | awk -v output="$wanted" '$1 == output && $2 == "connected" {print $1; exit}')
  if [[ -z "$candidate" ]]; then
    candidate=$(xrandr --query | awk -v type="$prefix" '$1 ~ ("^" type "-") && $2 == "connected" {print $1; exit}')
  fi
  [[ -n "$candidate" ]] || { echo "Saída Xorg não encontrada para: $wanted" >&2; return 1; }
  printf '%s\n' "$candidate"
}
VGA_OUTPUT=$(resolve_x_output "$VGA_OUTPUT")
echo "Saída Xorg do contador: VGA=$VGA_OUTPUT"

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

# O conteúdo do TV box é servido por HTTP, sem depender de uma saída local HDMI.
launch clock.html "$vga_geometry" /var/lib/viewcpjc/chromium-vga
fullscreen_window "Contador VGA" || true
wait
