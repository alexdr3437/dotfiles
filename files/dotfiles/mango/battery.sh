#!/usr/bin/env sh
# Battery backend.
#   battery.sh status → eww JSON   {laptop:{present,percent,glyph,detail}, devices:[{name,percent,glyph}]}
#   battery.sh bar    → waybar JSON {text, tooltip, class}; also fires the low-battery warning
#   battery.sh bar draw → waybar JSON, power draw in W: battery when discharging, else CPU package (RAPL) + GPU
#   battery.sh warn PERCENT STATE [DETAIL] → what bar calls for the laptop battery; run by hand to test
# Sources: upower (laptop + HID devices) and bt.sh (BLE devices via bluez; needs Experimental=true).
# Low-battery warning: one critical notification per $warn_levels threshold crossed while
# discharging, last level in $cache_dir/battery.warned (cleared when charging). waybar polls `bar`
# every 30 s; upower powers off at 2 % as the last resort (modules/mango.nix).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
warn_levels="20 10"
warned="$cache_dir/battery.warned"

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

# warn PERCENT STATE [DETAIL]: notify when a new threshold has been crossed on the way down
warn() {
  pct=$1; bstate=$2; detail=$3
  if [ "$bstate" != discharging ]; then rm -f "$warned"; return 0; fi
  level=""
  for l in $warn_levels; do [ "$pct" -le "$l" ] && level=$l; done   # lowest threshold at or above pct
  [ -n "$level" ] || { rm -f "$warned"; return 0; }
  [ "$(cat "$warned" 2>/dev/null)" = "$level" ] && return 0
  echo "$level" > "$warned"
  notify-send -u critical -a battery -i battery-caution \
    -h string:x-canonical-private-synchronous:battery \
    "Battery low: ${pct}%" "${detail:-plug in soon}"
}

bar() {
  s=$(status)
  # shellcheck disable=SC2046  # three words: percent state detail-tail
  printf '%s' "$s" | jq -r 'select(.laptop.present) | .laptop | "\(.percent) \(.detail)"' \
    | { read -r p rest && warn "$p" "$(printf '%s' "$rest" | sed -n 's/^[0-9]*% · \([a-z-]*\).*/\1/p')" "$rest"; }
  printf '%s' "$s" | jq -c '
    (if .laptop.present then "\(.laptop.glyph) \(.laptop.percent)%"
     elif (.devices | length) > 0 then "\(.devices[0].glyph) \(.devices[0].percent)%"
     else "󰂑" end) as $text
    | ([.laptop | select(.present) | "laptop  \(.detail)"] + (.devices | map("\(.name)  \(.percent)%"))) as $lines
    | {text: $text,
       tooltip: (if ($lines | length) > 0 then ($lines | join("\n")) else "no batteries" end),
       class: (if ((.laptop.present and .laptop.percent < 20) or any(.devices[]; .percent < 20)) then "low" else "ok" end)}'
}

# bar draw: power draw in W, whatever the source. A discharging battery gives the whole machine
# (power_now). Otherwise, plugged in or a desktop, there is no wall meter: the CPU package comes
# from Intel RAPL (energy_uj counters; the previous reading per zone is kept in $cache_dir/draw.rapl;
# root-only by default, modules/mango.nix opens it) and the GPU from nvidia-smi where the driver
# reports it (the desktop's 4060 says N/A). The tooltip names the parts. Empty text when nothing
# is readable, which hides the module; the first RAPL run only seeds the counters. class "high"
# above $draw_high W (laptop 20, desktop in hosts/desktop/env.sh). $rapl_dir overrides the sysfs
# directory for a dry run with fake counters.
draw() {
  draw_high=${draw_high:-20}
  emit() {  # microwatts, tooltip
    jq -cn --argjson uw "$1" --arg tip "$2" --argjson high "$draw_high" '($uw / 1000000) as $w
      | {text: "󱐋 \(($w * 10 | round) / 10)W", tooltip: $tip, class: (if $w > $high then "high" else "ok" end)}'
  }
  for b in /sys/class/power_supply/BAT*; do
    [ "$(cat "$b/status" 2>/dev/null)" = Discharging ] || continue
    uw=$(cat "$b/power_now" 2>/dev/null) && [ -n "$uw" ] || continue
    emit "$uw" "battery discharge: the whole machine"
    return
  done
  tip=""; total=0
  # CPU package(s): the top-level RAPL zones (the core/uncore subzones sit inside them). Each
  # counter wraps at its own max_energy_range_uj (about 17 min at full load), so the delta is
  # per zone. State file: a timestamp line, then "zone energy_uj" lines.
  state="$cache_dir/draw.rapl"
  prev=$([ -r "$state" ] && cat "$state")
  now=$(date +%s%N); new="$now"; delta=0; seen=0
  for z in ${rapl_dir:-/sys/devices/virtual/powercap/intel-rapl}/intel-rapl:*; do
    uj=$(cat "$z/energy_uj" 2>/dev/null) && [ -n "$uj" ] || continue
    n=${z##*/}
    new="$new
$n $uj"
    p=$(printf '%s\n' "$prev" | awk -v n="$n" '$1 == n { print $2 }')
    [ -n "$p" ] || continue
    d=$((uj - p))
    [ "$d" -lt 0 ] && d=$((d + $(cat "$z/max_energy_range_uj")))
    delta=$((delta + d)); seen=1
  done
  if [ "$new" != "$now" ]; then
    mkdir -p "$cache_dir"; printf '%s\n' "$new" > "$state"
  fi
  if [ "$seen" = 1 ]; then
    dt=$(( (now - ${prev%%
*}) / 1000000 ))                               # ms since the previous reading
    if [ "$dt" -gt 0 ]; then
      total=$((delta * 1000 / dt))                 # µJ / ms * 1000 = µW
      tip="CPU package $(awk -v uw="$total" 'BEGIN { printf "%.1f", uw / 1000000 }') W"
    fi
  fi
  if command -v nvidia-smi >/dev/null; then
    g=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)
    case $g in
      *[0-9]*) gpu=$(awk -v w="$g" 'BEGIN { printf "%d", w * 1000000 }')
               total=$((total + gpu)); tip="${tip:+$tip · }GPU $g W" ;;
    esac
  fi
  [ -n "$tip" ] || { echo '{"text":""}'; return; }
  emit "$total" "$tip
chip sensors, not the wall"
}

case "$1" in
  status) status ;;
  bar) if [ "$2" = draw ]; then draw; else bar; fi ;;
  warn) [ -n "$3" ] || usage "warn PERCENT STATE [DETAIL]"; warn "$2" "$3" "$4" ;;
  *) usage "status|bar [draw]|warn PERCENT STATE [DETAIL]" ;;
esac
