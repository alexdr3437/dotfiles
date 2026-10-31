#!/usr/bin/env sh
# Idle handling (swayidle), with timers that depend on the power source:
#   on AC:      lock after $ac_lock_min, screens off after $ac_off_min, never suspend
#   on battery: lock after $bat_lock_min, suspend after $bat_suspend_min
# Lock before sleep and on `loginctl lock-session` in both. Needs swayidle + wlopm (modules/mango.nix).
#   idle.sh status      → eww JSON {available, active, source, lock_min, off_min, suspend_min}
#   idle.sh start | stop | toggle
#   idle.sh watch       → restart swayidle when the power source changes (autostart.sh)
#   idle.sh on-battery  → exit 0 on battery, 1 on AC (monitors.sh)
# A machine without a mains supply (the desktop) counts as AC. Override the timers in
# hosts/<host>/env.sh; the values here are the defaults for both machines.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
ac_lock_min=${ac_lock_min:-5}
ac_off_min=${ac_off_min:-60}
bat_lock_min=${bat_lock_min:-2}
bat_suspend_min=${bat_suspend_min:-5}

available() { command -v swayidle >/dev/null && command -v wlopm >/dev/null; }
active() { pgrep -f '^swayidle' >/dev/null; }

# ac | battery, from /sys: a Mains supply that is offline means battery
power_source() {
  for p in /sys/class/power_supply/*; do
    [ "$(cat "$p/type" 2>/dev/null)" = Mains ] || continue
    [ "$(cat "$p/online" 2>/dev/null)" = 1 ] || { echo battery; return; }
  done
  echo ac
}
has_mains() { for p in /sys/class/power_supply/*; do [ "$(cat "$p/type" 2>/dev/null)" = Mains ] && return 0; done; return 1; }

start() {
  available || return 0
  active && return 0
  if [ "$(power_source)" = battery ]; then
    setsid -f swayidle -w \
      timeout $((bat_lock_min * 60)) "$dir/lock.sh" \
      timeout $((bat_suspend_min * 60)) "systemctl suspend" \
      lock "$dir/lock.sh" before-sleep "$dir/lock.sh" >/dev/null 2>&1 </dev/null
  else
    # wlopm --on '*' cannot re-light a panel monitors.sh disabled: mango drops a
    # disabled output from the layout, which removes its wl_output global
    setsid -f swayidle -w \
      timeout $((ac_lock_min * 60)) "$dir/lock.sh" \
      timeout $((ac_off_min * 60)) "wlopm --off '*'" resume "wlopm --on '*'" \
      lock "$dir/lock.sh" before-sleep "$dir/lock.sh" >/dev/null 2>&1 </dev/null
  fi
}
stop() { pkill -f '^swayidle'; }
restart() { stop; sleep 0.2; start; }

# upower --monitor prints a line on any device change (battery %, mouse battery, ...);
# only a change of source restarts swayidle. Skipped where there is no mains supply.
watch() {
  has_mains || return 0
  last=$(power_source)
  upower --monitor 2>/dev/null | while read -r _; do
    now=$(power_source)
    [ "$now" = "$last" ] && continue
    last=$now
    active && restart
    refresh idle "$("$0" status)"
  done
}

case "$1" in
  status)
    a=false; available && a=true
    r=false; active && r=true
    src=$(power_source); lm=$ac_lock_min; [ "$src" = battery ] && lm=$bat_lock_min
    printf '{"available":%s,"active":%s,"source":"%s","lock_min":%d,"off_min":%d,"suspend_min":%d}\n' \
      "$a" "$r" "$src" "$lm" "$ac_off_min" "$bat_suspend_min" ;;
  start) start ;;
  stop) stop ;;
  toggle) if active; then run "$0" stop; else run "$0" start; fi; sleep 0.3
          refresh idle "$("$0" status)" ;;
  watch) watch ;;
  on-battery) [ "$(power_source)" = battery ] ;;
  *) usage "status|start|stop|toggle|watch|on-battery" ;;
esac
