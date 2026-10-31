#!/usr/bin/env sh
# Settings backend for the eww popup.
#   settings.sh status                → JSON {theme, themes:[..], dnd, nl:{active,start,stop,after}}
#   settings.sh theme NAME | dnd | nightlight | restart
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

status() {
  theme=$(basename "$(readlink "$state_dir/theme.css")" .css)
  themes=$(ls "$dir/themes" | sed 's/\.css$//' | jq -R -s -c 'split("\n") | map(select(length > 0))')
  dnd=$(swaync-client -D 2>/dev/null); [ "$dnd" = true ] || dnd=false
  nl=$("$dir/nightlight.sh" status)
  jq -cn --arg theme "$theme" --argjson themes "$themes" --argjson dnd "$dnd" --argjson nl "$nl" \
    '{theme:$theme, themes:$themes, dnd:$dnd, nl:$nl}'
}

case "$1" in
  status) status ;;
  theme) run "$dir/theme.sh" "$2" >/dev/null 2>&1; refresh settings "$(status)" ;;
  dnd) run swaync-client -d >/dev/null 2>&1; refresh settings "$(status)" ;;
  nightlight) run "$dir/nightlight.sh" toggle; sleep 0.5; refresh settings "$(status)" ;;
  restart) exec "$dir/run.sh" "$dir/autostart.sh" ;;   # bar, notifications, popups, wallpaper — everything
  *) usage "status|theme NAME|dnd|nightlight|restart" ;;
esac
