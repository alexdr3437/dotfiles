#!/usr/bin/env sh
# Battery backend.
#   battery.sh status → eww JSON   {laptop:{present,percent,glyph,detail}, devices:[{name,percent,glyph}]}
#   battery.sh bar    → waybar JSON {text, tooltip, class}
# Sources: upower (laptop + HID devices) and bt.sh (BLE devices via bluez; needs Experimental=true).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

laptop_glyph() {  # percent, state
  if [ "$2" = "charging" ] || [ "$2" = "fully-charged" ]; then echo "󰂄"; return; fi
  case $(( $1 / 10 )) in
    0) echo "󰁺" ;; 1) echo "󰁻" ;; 2) echo "󰁼" ;; 3) echo "󰁽" ;; 4) echo "󰁾" ;;
    5) echo "󰁿" ;; 6) echo "󰂀" ;; 7) echo "󰂁" ;; 8) echo "󰂂" ;; *) echo "󰁹" ;;
  esac
}

status() {
  laptop='{"present":false,"percent":0,"glyph":"","detail":""}'
  devices=""
  for d in $(upower -e | grep -v DisplayDevice); do
    info=$(upower -i "$d")
    pct=$(printf '%s\n' "$info" | sed -n 's/^ *percentage: *\([0-9]*\)%.*/\1/p' | head -1)
    [ -n "$pct" ] || continue
    bstate=$(printf '%s\n' "$info" | sed -n 's/^ *state: *//p' | head -1)
    model=$(printf '%s\n' "$info" | sed -n 's/^ *model: *//p' | head -1)
    kind=$(printf '%s\n' "$info" | sed -n 's/^  \([a-z-]*\)$/\1/p' | head -1)
    if printf '%s\n' "$info" | grep -q "power supply: *yes"; then
      time=$(printf '%s\n' "$info" | sed -n 's/^ *time to \(empty\|full\): *\(.*\)/\2 to \1/p' | head -1)
      laptop=$(jq -cn --argjson p "$pct" --arg g "$(laptop_glyph "$pct" "$bstate")" \
        --arg d "${pct}% · ${bstate}${time:+ · $time}" '{present:true, percent:$p, glyph:$g, detail:$d}')
    else
      devices="$devices$(jq -cn --arg n "${model:-$kind}" --argjson p "$pct" --arg g "$(device_glyph "$kind")" \
        '{name:$n, percent:$p, glyph:$g}')
"
    fi
  done
  # BLE devices report battery through bluez rather than upower; bt.sh is the one
  # place that parses bluetoothctl, so take its connected devices that have a battery
  ble=$("$dir/bt.sh" status | jq -c '[.devices[] | select(.connected and .battery != "") | {name, percent: (.battery | tonumber), glyph}]')
  printf '%s' "$devices" | jq -cs --argjson laptop "$laptop" --argjson ble "${ble:-[]}" \
    '{laptop:$laptop, devices:((. + $ble) | unique_by(.name) | sort_by(.percent))}'
}

bar() {
  status | jq -c '
    (if .laptop.present then "\(.laptop.glyph) \(.laptop.percent)%"
     elif (.devices | length) > 0 then "\(.devices[0].glyph) \(.devices[0].percent)%"
     else "󰂑" end) as $text
    | ([.laptop | select(.present) | "laptop  \(.detail)"] + (.devices | map("\(.name)  \(.percent)%"))) as $lines
    | {text: $text,
       tooltip: (if ($lines | length) > 0 then ($lines | join("\n")) else "no batteries" end),
       class: (if ((.laptop.present and .laptop.percent < 20) or any(.devices[]; .percent < 20)) then "low" else "ok" end)}'
}

case "$1" in
  status) status ;;
  bar) bar ;;
  *) usage "status|bar" ;;
esac
