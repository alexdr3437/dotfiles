#!/usr/bin/env sh
# Night light (wlsunset), scheduled from today's real sunrise/sunset (via weather.sh / Open-Meteo):
# warm from $after minutes after sunset until sunrise. The daemon re-reads the sun times every 6h
# of wall-clock time and only restarts wlsunset when they change.
#   nightlight.sh auto    → start unless the user turned it off (autostart.sh)
#   nightlight.sh start | stop | toggle | status | daemon
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
off_flag="$state_dir/nightlight.off"   # exists → user turned it off; survives logins
after=30                               # minutes after sunset
temp=4000                              # night colour temperature (K)

suntimes() {   # → $start (go warm) $stop (back to normal), HH:MM. Cached weather only: never hits the network.
  w=$("$dir/weather.sh" cached 2>/dev/null)
  sunset=$(printf '%s' "$w" | jq -r '.sunset24 // empty')
  sunrise=$(printf '%s' "$w" | jq -r '.sunrise24 // empty')
  if [ -n "$sunset" ] && [ -n "$sunrise" ]; then
    start=$(date -d "today $sunset $after min" +%H:%M); stop=$sunrise
  else
    start="19:00"; stop="07:00"   # no weather data: sensible fallback
  fi
}

daemon() {
  last=""; next=0
  while :; do
    if [ "$(date +%s)" -ge "$next" ]; then
      "$dir/weather.sh" status >/dev/null 2>&1   # refresh the cache (network) before reading it
      suntimes
      if [ "$start $stop" != "$last" ]; then
        pkill -f '^wlsunset' 2>/dev/null
        setsid -f wlsunset -t "$temp" -T 6500 -s "$start" -S "$stop" >/dev/null 2>&1 </dev/null
        last="$start $stop"
      fi
      next=$(( $(date +%s) + 21600 ))
    fi
    sleep 600   # short naps: one long sleep would not notice the hours that pass during suspend
  done
}

running() { pgrep -f 'nightlight.sh daemon' >/dev/null; }

case "$1" in
  daemon) daemon ;;
  start) rm -f "$off_flag"; running || setsid -f "$0" daemon >/dev/null 2>&1 </dev/null ;;
  stop) touch "$off_flag"; pkill -f 'nightlight.sh daemon' 2>/dev/null; pkill -f '^wlsunset' 2>/dev/null ;;
  toggle) if running; then "$0" stop; else "$0" start; fi ;;
  auto) [ -f "$off_flag" ] || "$0" start ;;
  status)
    a=false; running && a=true
    suntimes
    printf '{"active":%s,"start":"%s","stop":"%s","after":%d}\n' "$a" "$(date -d "$start" '+%-I:%M %p')" "$(date -d "$stop" '+%-I:%M %p')" "$after" ;;
  *) usage "auto|start|stop|toggle|status|daemon" ;;
esac
