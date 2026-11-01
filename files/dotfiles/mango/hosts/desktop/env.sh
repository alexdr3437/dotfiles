#!/usr/bin/env sh
# Desktop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
lock_monitor=HDMI-A-1  # lock.sh: the password form starts on the 4K
# no internal_monitor: monitors.sh's panel logic is a no-op here (set it in the environment for a dry run)
# idle.sh timers (minutes); always AC here: password-free lock screen at 5, password lock
# and screens off at 120 (mango README, "Lock screen")
soft_lock_min=5
ac_lock_min=120
# Other overrides: ac_off_min= hint_min= (defaults in idle.sh)
