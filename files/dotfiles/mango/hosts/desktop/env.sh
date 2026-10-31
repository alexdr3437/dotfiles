#!/usr/bin/env sh
# Desktop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
lock_min=10          # idle.sh: lock after this many minutes
off_min=15           # idle.sh: screens off after this many minutes
lock_monitor=HDMI-A-1  # lock.sh: the 4K gets the password form, the other only the clock
