#!/usr/bin/env sh
# Idle handling: lock after $lock_min minutes, screens off after $off_min (back on when you return),
# lock before sleep. Needs swayidle + wlopm (modules/mango.nix).
#   idle.sh status → eww JSON {available, active, lock_min, off_min}
#   idle.sh start | stop | toggle
dir="$HOME/.config/mango"
lock_min=10
off_min=15

available() { command -v swayidle >/dev/null && command -v wlopm >/dev/null; }
active() { pgrep -f '^swayidle' >/dev/null; }

start() {
  available || return 0
  active && return 0
  setsid -f swayidle -w \
    timeout $((lock_min * 60)) "$dir/lock.sh" \
    timeout $((off_min * 60)) "wlopm --off '*'" resume "wlopm --on '*'" \
    before-sleep "$dir/lock.sh" >/dev/null 2>&1 </dev/null
}
stop() { pkill -f '^swayidle'; }

case "$1" in
  status)
    a=false; available && a=true
    r=false; active && r=true
    printf '{"available":%s,"active":%s,"lock_min":%d,"off_min":%d}\n' "$a" "$r" "$lock_min" "$off_min" ;;
  start) start ;;
  stop) stop ;;
  toggle) if active; then "$dir/run.sh" "$0" stop; else "$dir/run.sh" "$0" start; fi; sleep 0.3
          "$dir/ewwc.sh" update "idle=$("$0" status)" >/dev/null 2>&1 ;;
  *) echo "usage: idle.sh status|start|stop|toggle" >&2; exit 1 ;;
esac
