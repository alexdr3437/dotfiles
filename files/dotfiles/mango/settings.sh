#!/usr/bin/env sh
# Settings backend for the eww popup.
#   settings.sh status                → JSON {theme, themes:[..], dnd, nightlight, nightlight_available}
#   settings.sh theme NAME | dnd | nightlight | restart
dir="$HOME/.config/mango"
ewwc="$dir/ewwc.sh"

status() {
  theme=$(readlink "$dir/theme.css" | sed 's|themes/||; s/\.css$//')
  themes=$(ls "$dir/themes" | sed 's/\.css$//' | jq -R -s -c 'split("\n") | map(select(length > 0))')
  dnd=$(swaync-client -D 2>/dev/null); [ "$dnd" = true ] || dnd=false
  nl=$("$dir/nightlight.sh" status)
  jq -cn --arg theme "$theme" --argjson themes "$themes" --argjson dnd "$dnd" --argjson nl "$nl" \
    '{theme:$theme, themes:$themes, dnd:$dnd, nl:$nl}'
}

refresh() { "$ewwc" update "settings=$(status)" >/dev/null 2>&1; }

case "$1" in
  status) status ;;
  theme) "$dir/run.sh" "$dir/theme.sh" "$2" >/dev/null 2>&1; refresh ;;
  dnd) "$dir/run.sh" swaync-client -d >/dev/null 2>&1; refresh ;;
  nightlight) "$dir/run.sh" "$dir/nightlight.sh" toggle; sleep 0.5; refresh ;;
  restart) exec "$dir/run.sh" "$dir/autostart.sh" ;;   # bar, notifications, popups, wallpaper — everything
  *) echo "usage: settings.sh status|theme NAME|dnd|nightlight|restart" >&2; exit 1 ;;
esac
