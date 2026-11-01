#!/usr/bin/env sh
# Lock the screen. gtklock: clock + password box (gtklock.css, themed) over the
# blurred wallpaper that wallpaper.sh keeps in ~/.cache/mango/lock.png.
# Falls back to swaylock with the theme's base colour if gtklock isn't installed.
#   lock.sh          lock (Alt+m, idle.sh, lid close on AC, the power popup, session start)
#   lock.sh relock   replace the running locker with a fresh one (Ctrl+Alt+Delete, which
#                    works while locked): the way out if the password form is ever stuck.
#                    mango keeps the session locked while no locker runs and hands the
#                    lock to the next one, so this never unlocks anything.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
bg="$cache_dir/lock.png"
locker='(^|/)\.?(gtk|sway)lock(-wrapped)?( |$)'   # pkill -f pattern: the locker, never a shell running lock.sh

lock() {
  if command -v gtklock >/dev/null; then
    # long options only: -d is both --daemonize and --date-format
    # --start-hidden / --idle-hide: only the clock shows until a key press or mouse
    # move; the form folds away again after $hide_after seconds of inactivity.
    # --monitor-priority: which screen gets the form at first (others show only the
    # clock); $lock_monitor comes from hosts/<host>/env.sh, empty lets gtklock choose.
    # The form then follows the screen mango gives the keyboard and survives monitors
    # going away and coming back (gtklock-monitor-hotplug.patch, modules/mango.nix).
    # --daemonize returns once the session is locked: 0, or non-zero if it failed.
    hide_after=15
    [ -s "$bg" ] || bg=""
    gtklock --daemonize --style "$dir/gtklock.css" \
      --time-format '%-I:%M %p' --date-format '%A, %B %-d' \
      --start-hidden --idle-hide --idle-timeout "$hide_after" \
      ${lock_monitor:+--monitor-priority "$lock_monitor"} \
      ${bg:+--background "$bg"}
    return
  fi
  base=$(sed -n 's/^@define-color base *#\([0-9a-fA-F]*\);.*/\1/p' "$state_dir/theme.css" 2>/dev/null)
  swaylock -f -c "${base:-1e1e2e}"
}

case "${1:-}" in
  relock)
    pkill -u "$(id -u)" -f "$locker"
    # mango refuses a new lock while the old one is still registered, so wait for the
    # old locker to be gone, then retry until one holds the lock (a few seconds at most)
    i=0; while pgrep -u "$(id -u)" -f "$locker" >/dev/null && [ $i -lt 30 ]; do sleep 0.1; i=$((i + 1)); done
    pkill -9 -u "$(id -u)" -f "$locker"
    i=0; until lock || [ $i -ge 5 ]; do sleep 1; i=$((i + 1)); done
    ;;
  *) lock ;;
esac
