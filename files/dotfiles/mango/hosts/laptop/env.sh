#!/usr/bin/env sh
# Work laptop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
internal_monitor=eDP-1   # monitors.sh: off while another monitor is connected
lock_monitor=            # lock.sh: empty → gtklock picks the form's monitor itself
# idle.sh timers (minutes) default to AC lock 5 / screens off 120, battery lock 2 / suspend 5.
# Override here: ac_lock_min= ac_off_min= bat_lock_min= bat_suspend_min=
