#!/usr/bin/env sh
# Work laptop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
lock_min=5           # idle.sh: lock after this many minutes
off_min=10           # idle.sh: screens off after this many minutes
lock_monitor=        # lock.sh: empty → gtklock picks the form's monitor itself
