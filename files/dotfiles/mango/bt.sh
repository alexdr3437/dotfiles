#!/usr/bin/env sh
# Bluetooth backend for the eww popup.
#   bt.sh status                → JSON {powered, devices:[{mac,name,connected,battery,glyph}]}
#   bt.sh toggle | connect MAC | disconnect MAC | forget MAC
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

powered() { bluetoothctl show | grep -q "Powered: yes"; }

status() {
  # one bluetoothctl session for `show` plus every `info`, parsed by one awk, built by one jq:
  # ~80 ms for three devices instead of a bluetoothctl + jq + sed + grep per device (~250 ms)
  macs=$(bluetoothctl devices Paired | awk '{print $2}')
  { echo show; for m in $macs; do echo "info $m"; done; } | bluetoothctl 2>/dev/null \
    | awk '
        { gsub(/\033\[[0-9;]*[A-Za-z]/, "") }                                   # colour codes, if any
        /^Device [0-9A-Fa-f:]+ / { mac = $2; if (!(mac in seen)) { seen[mac] = 1; order[++n] = mac }; next }
        mac == "" && /Powered: yes/ { powered = "true" }                        # from `show`, before any Device
        mac != "" && /^[ \t]*Alias: / { sub(/^[ \t]*Alias: /, ""); alias[mac] = $0 }
        mac != "" && /^[ \t]*Connected: yes/ { conn[mac] = 1 }                  # (not LE.Connected)
        mac != "" && /^[ \t]*Icon: / { icon[mac] = $2 }
        mac != "" && /Battery Percentage:/ && match($0, /\([0-9]+\)/) { bat[mac] = substr($0, RSTART + 1, RLENGTH - 2) }
        END {
          printf "powered\037%s\n", (powered == "" ? "false" : powered)
          for (i = 1; i <= n; i++) { m = order[i]; printf "%s\037%s\037%d\037%s\037%s\n", m, alias[m], (m in conn), bat[m], icon[m] }
        }' \
    | while IFS="$(printf '\037')" read -r mac alias connected battery icon; do   # icon → glyph (lib.sh), no forks. \037 (not tab): empty fields must survive `read`
        [ "$mac" = powered ] && { printf '%s\037%s\n' "$mac" "$alias"; continue; }
        printf '%s\037%s\037%s\037%s\037%s\n' "$mac" "$alias" "$connected" "$battery" "$(device_glyph "$icon")"
      done \
    | jq -R -s -c '
        [split("\n")[] | select(length > 0) | split("\u001f")]
        | (map(select(.[0] == "powered")) | first | .[1] == "true") as $p
        | [.[] | select(.[0] != "powered") | {mac: .[0], name: .[1], connected: (.[2] == "1"), battery: .[3], glyph: .[4]}]
        | {powered: $p, devices: sort_by(.connected | not)}'
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
