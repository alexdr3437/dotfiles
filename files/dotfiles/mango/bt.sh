#!/usr/bin/env sh
# Bluetooth backend for the eww popup.
#   bt.sh status                → JSON {powered, devices:[{mac,name,connected,battery,glyph}]}
#   bt.sh toggle | connect MAC | disconnect MAC | forget MAC
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

powered() { bluetoothctl show | grep -q "Powered: yes"; }

status() {
  p=false; powered && p=true
  devices=$(bluetoothctl devices Paired | while read -r _ mac name; do
    info=$(bluetoothctl info "$mac")
    connected=false; printf '%s\n' "$info" | grep -q "Connected: yes" && connected=true
    battery=$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\([0-9]*\)).*/\1/p' | head -1)
    icon=$(printf '%s\n' "$info" | sed -n 's/^\s*Icon: //p' | head -1)
    jq -cn --arg mac "$mac" --arg name "$name" --argjson connected "$connected" \
      --arg battery "$battery" --arg glyph "$(device_glyph "$icon")" \
      '{mac:$mac, name:$name, connected:$connected, battery:$battery, glyph:$glyph}'
  done | jq -cs 'sort_by(.connected | not)')
  jq -cn --argjson powered "$p" --argjson devices "${devices:-[]}" '{powered:$powered, devices:$devices}'
}

case "$1" in
  status) status ;;
  toggle)
    if powered; then run bluetoothctl power off; else run bluetoothctl power on; fi
    sleep 0.5; refresh bt "$(status)" ;;
  connect) run bluetoothctl connect "$2" >/dev/null; refresh bt "$(status)" ;;
  disconnect) run bluetoothctl disconnect "$2" >/dev/null; refresh bt "$(status)" ;;
  forget) run bluetoothctl remove "$2" >/dev/null; refresh bt "$(status)" ;;
  *) usage "status|toggle|connect MAC|disconnect MAC|forget MAC" ;;
esac
