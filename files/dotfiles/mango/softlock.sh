#!/usr/bin/env sh
# Soft lock: the lock screen without a password, for the first stretch of idle time on
# machines that set $soft_lock_min (hosts/<host>/env.sh; the desktop). idle.sh shows it from
# a swayidle timeout and hides it from that timeout's resume, so the first key press or
# pointer move ends it; the real lock (lock.sh, password) still follows after $ac_lock_min.
# It is the blurred wallpaper and the clock on every monitor (eww window `softlock`). The
# window takes the keyboard, so the waking key stops there instead of reaching the app below.
# A click also hides it, and Super+Escape (popup.sh close) closes it with every popup.
# waybar is stopped while it shows (bar.sh stop / show): eww can't make a window ignore the
# bar's reserved space, so the window would start below the bar. bar.sh show only starts
# the bar once, so a second hide (the resume and the waking click both run hide) is harmless.
#   softlock.sh show | hide
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

case "$1" in
  show)
    "$dir/bar.sh" stop
    set --
    for m in $("$dir/monitors.sh" names); do
      set -- "$@" "softlock:softlock-$m" --arg "softlock-$m:mon=$m"
    done
    [ $# -gt 0 ] && ewwc open-many "$@" >/dev/null 2>&1 ;;
  hide)
    ids=$(ewwc active-windows 2>/dev/null | cut -d: -f1 | grep '^softlock-')
    # shellcheck disable=SC2086  # whitespace-separated window ids
    [ -n "$ids" ] && ewwc close $ids >/dev/null 2>&1
    "$dir/bar.sh" show ;;
  *) usage "show|hide" ;;
esac
exit 0
