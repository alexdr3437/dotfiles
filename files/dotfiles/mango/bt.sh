#!/usr/bin/env sh
# Bluetooth backend for the eww popup.
#   bt.sh status                → JSON {powered, devices:[{mac,name,connected,battery,glyph}]}
#   bt.sh toggle | connect MAC | disconnect MAC | forget MAC
cfg="$HOME/.config/mango/eww"

status() {
  powered=$(bluetoothctl show | grep -q "Powered: yes" && echo true || echo false)
  devices=$(bluetoothctl devices Paired | while read -r _ mac name; do
    info=$(bluetoothctl info "$mac")
    connected=$(printf '%s\n' "$info" | grep -q "Connected: yes" && echo true || echo false)
    battery=$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\([0-9]*\)).*/\1/p' | head -1)
    case $(printf '%s\n' "$info" | sed -n 's/^\s*Icon: //p' | head -1) in
      input-keyboard) glyph="󰌌" ;;
      input-mouse) glyph="󰍽" ;;
      audio-headphones|audio-headset) glyph="󰋋" ;;
      audio-card) glyph="󰓃" ;;
      phone) glyph="󰏲" ;;
      *) glyph="󰂯" ;;
    esac
    jq -cn --arg mac "$mac" --arg name "$name" --argjson connected "$connected" \
      --arg battery "$battery" --arg glyph "$glyph" \
      '{mac:$mac, name:$name, connected:$connected, battery:$battery, glyph:$glyph}'
  done | jq -cs 'sort_by(.connected | not)')
  jq -cn --argjson powered "$powered" --argjson devices "${devices:-[]}" \
    '{powered:$powered, devices:$devices}'
}

# push fresh state to eww right away instead of waiting for the next poll
refresh() { "$HOME/.config/mango/ewwc.sh" update "bt=$(status)" >/dev/null 2>&1; }

case "$1" in
  status) status ;;
  toggle)
    if bluetoothctl show | grep -q "Powered: yes"; then "$HOME/.config/mango/run.sh" bluetoothctl power off; else "$HOME/.config/mango/run.sh" bluetoothctl power on; fi
    sleep 0.5; refresh ;;
  connect) "$HOME/.config/mango/run.sh" bluetoothctl connect "$2" >/dev/null; refresh ;;
  disconnect) "$HOME/.config/mango/run.sh" bluetoothctl disconnect "$2" >/dev/null; refresh ;;
  forget) "$HOME/.config/mango/run.sh" bluetoothctl remove "$2" >/dev/null; refresh ;;
  *) echo "usage: bt.sh status|toggle|connect MAC|disconnect MAC|forget MAC" >&2; exit 1 ;;
esac
