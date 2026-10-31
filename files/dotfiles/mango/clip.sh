#!/usr/bin/env sh
# Clipboard history (Plasma's klipper, redone with cliphist).
#   clip.sh watch  → daemon (autostart.sh): record every text and image copy into cliphist
#   clip.sh pick   → rofi over the history, newest first (Super+v); the pick becomes the clipboard
#   clip.sh wipe   → forget the history
# cliphist keeps the store in ~/.cache/cliphist/db; images show as "[[ binary data … png … ]]".
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
tab="$(printf '\t')"

case "$1" in
  watch)
    pkill -f '^wl-paste --watch cliphist'; pkill -f '^wl-paste --type image --watch cliphist'
    wl-paste --watch cliphist store &
    wl-paste --type image --watch cliphist store &
    wait ;;
  pick)
    idx=$(cliphist list | rofi -dmenu -i -p "󰅍" -format i \
            -display-columns 2 -display-column-separator "$tab" \
            -theme "$dir/rofi.rasi" -theme-str 'listview { lines: 12; } window { width: 760px; }') || exit 0
    cliphist list | sed -n "$((idx + 1))p" | cliphist decode | wl-copy ;;
  wipe) cliphist wipe ;;
  *) usage "watch | pick | wipe" ;;
esac
