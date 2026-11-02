#!/usr/bin/env sh
# The top bar (waybar), run by a small supervisor loop that starts it again if it exits.
#   bar.sh restart   → fresh waybar + supervisor (autostart.sh)
#   bar.sh stop      → stop it and keep it stopped (softlock.sh show)
#   bar.sh show      → start it again after stop; a no-op unless stopped (softlock.sh hide)
# The soft lock stops and starts the bar instead of toggling it with SIGUSR1: the toggle is
# per bar, and waybar replaces a monitor's bar with a new, visible one when the monitor
# sleeps or is replugged, so the toggle that should bring the bar back hid the new bars.
# A fresh waybar always starts visible.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
off="$runtime_dir/mango-bar-off"   # exists while stopped on purpose; the supervisor then exits
log="$cache_dir/waybar.log"

kill_all() {   # supervisor first, so it doesn't start the waybar killed next
  pkill -f "$dir/bar.sh supervise"
  pkill -f '^waybar '
}
launch() { setsid -f "$dir/bar.sh" supervise >/dev/null 2>&1 </dev/null; }

supervise() {
  : >"$log"
  while [ ! -e "$off" ]; do
    started=$(date +%s)
    waybar -c "$dir/waybar.jsonc" -s "$dir/waybar.css" >>"$log" 2>&1
    code=$?
    [ -e "$off" ] && break
    echo "[bar.sh] $(date '+%F %T') waybar exited ($code), restarting" >>"$log"
    # dying right after start (e.g. a broken config) backs off instead of spinning
    if [ $(( $(date +%s) - started )) -lt 10 ]; then sleep 5; else sleep 1; fi
  done
}

case "$1" in
  restart) kill_all; rm -f "$off"; launch ;;
  stop) : >"$off"; kill_all ;;
  show) rm "$off" 2>/dev/null && { kill_all; launch; } ;;   # rm is atomic: of two callers only one starts it
  supervise) supervise ;;
  *) usage "restart|stop|show" ;;
esac
exit 0
