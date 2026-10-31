#!/usr/bin/env sh
# Lock the screen. gtklock: clock + password box (gtklock.css, themed) over the
# blurred wallpaper that wallpaper.sh keeps in ~/.cache/mango/lock.png.
# Falls back to swaylock with the theme's base colour if gtklock isn't installed.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
bg="$cache_dir/lock.png"

if command -v gtklock >/dev/null; then
  # long options only: -d is both --daemonize and --date-format
  # --start-hidden / --idle-hide: only the clock shows until a key press or mouse
  # move; the form folds away again after $hide_after seconds of inactivity.
  # --monitor-priority: which screen gets the form (others show only the clock);
  # $lock_monitor comes from hosts/<host>/env.sh, empty lets gtklock choose.
  hide_after=15
  [ -s "$bg" ] || bg=""
  exec gtklock --daemonize --style "$dir/gtklock.css" \
    --time-format '%-I:%M %p' --date-format '%A, %B %-d' \
    --start-hidden --idle-hide --idle-timeout "$hide_after" \
    ${lock_monitor:+--monitor-priority "$lock_monitor"} \
    ${bg:+--background "$bg"}
fi

base=$(sed -n 's/^@define-color base *#\([0-9a-fA-F]*\);.*/\1/p' "$state_dir/theme.css" 2>/dev/null)
exec swaylock -f -c "${base:-1e1e2e}"
