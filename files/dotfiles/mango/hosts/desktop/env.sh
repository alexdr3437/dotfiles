#!/usr/bin/env sh
# Desktop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
lock_monitor=HDMI-A-1  # lock.sh: the 4K gets the password form, the other only the clock
# no internal_monitor: monitors.sh is a no-op here (set it in the environment to dry-run status)
# idle.sh timers (minutes) are the shared defaults: AC lock 5 / screens off 60 (no
# mains supply here, so always AC). Override: ac_lock_min= ac_off_min=
