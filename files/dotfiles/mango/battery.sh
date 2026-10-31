#!/usr/bin/env sh
# Battery backend.
#   battery.sh status → eww JSON   {laptop:{present,percent,glyph,detail}, devices:[{name,percent,glyph}]}
#   battery.sh bar    → waybar JSON {text, tooltip, class}
# Sources: upower (laptop + HID devices) and bluetoothctl (BLE devices; needs bluez Experimental=true).

laptop_glyph() {  # percent, state
  if [ "$2" = "charging" ] || [ "$2" = "fully-charged" ]; then echo "󰂄"; return; fi
  case $(( $1 / 10 )) in
    0) echo "󰁺" ;; 1) echo "󰁻" ;; 2) echo "󰁼" ;; 3) echo "󰁽" ;; 4) echo "󰁾" ;;
    5) echo "󰁿" ;; 6) echo "󰂀" ;; 7) echo "󰂁" ;; 8) echo "󰂂" ;; *) echo "󰁹" ;;
  esac
}
kind_glyph() {
  case "$1" in
    mouse|input-mouse) echo "󰍽" ;; keyboard|input-keyboard) echo "󰌌" ;;
    headset|headphones|audio-headset|audio-headphones) echo "󰋋" ;;
    phone) echo "󰏲" ;; gaming-input) echo "󰊗" ;; *) echo "󰂯" ;;
  esac
}

status() {
  laptop='{"present":false,"percent":0,"glyph":"","detail":""}'
  devices=""
  for d in $(upower -e | grep -v DisplayDevice); do
    info=$(upower -i "$d")
    pct=$(printf '%s\n' "$info" | sed -n 's/^ *percentage: *\([0-9]*\)%.*/\1/p' | head -1)
    [ -n "$pct" ] || continue
    state=$(printf '%s\n' "$info" | sed -n 's/^ *state: *//p' | head -1)
    model=$(printf '%s\n' "$info" | sed -n 's/^ *model: *//p' | head -1)
    kind=$(printf '%s\n' "$info" | sed -n 's/^  \([a-z-]*\)$/\1/p' | head -1)
    if printf '%s\n' "$info" | grep -q "power supply: *yes"; then
      time=$(printf '%s\n' "$info" | sed -n 's/^ *time to \(empty\|full\): *\(.*\)/\2 to \1/p' | head -1)
      laptop=$(jq -cn --argjson p "$pct" --arg g "$(laptop_glyph "$pct" "$state")" \
        --arg d "${pct}% · ${state}${time:+ · $time}" '{present:true, percent:$p, glyph:$g, detail:$d}')
    else
      devices="$devices$(jq -cn --arg n "${model:-$kind}" --argjson p "$pct" --arg g "$(kind_glyph "$kind")" \
        '{name:$n, percent:$p, glyph:$g}')
"
    fi
  done
  # BLE devices report battery through bluez rather than upower
  for mac in $(bluetoothctl devices Connected | awk '{print $2}'); do
    info=$(bluetoothctl info "$mac")
    pct=$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\([0-9]*\)).*/\1/p' | head -1)
    [ -n "$pct" ] || continue
    name=$(printf '%s\n' "$info" | sed -n 's/^\s*Name: //p' | head -1)
    icon=$(printf '%s\n' "$info" | sed -n 's/^\s*Icon: //p' | head -1)
    devices="$devices$(jq -cn --arg n "$name" --argjson p "$pct" --arg g "$(kind_glyph "$icon")" '{name:$n, percent:$p, glyph:$g}')
"
  done
  printf '%s' "$devices" | jq -cs --argjson laptop "$laptop" \
    '{laptop:$laptop, devices:(unique_by(.name) | sort_by(.percent))}'
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
  *) echo "usage: battery.sh status|bar" >&2; exit 1 ;;
esac
