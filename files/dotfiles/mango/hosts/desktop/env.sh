#!/usr/bin/env sh
# Desktop: sourced by lib.sh (via ~/.config/mango-host/env.sh). Shell variables the
# scripts read; defaults live in the script that uses each one.
# shellcheck disable=SC2034  # variables are for the sourcing script
lock_monitor=HDMI-A-1  # lock.sh: the 4K gets the password form, the other only the clock
# no internal_monitor: monitors.sh's panel logic is a no-op here (set it in the environment for a dry run)
# idle.sh timers (minutes); no mains supply here, so always AC. After 5 idle minutes the
# password-free lock screen (softlock.sh), gone at the first key or pointer move; the real
# lock (password) after 2 hours, when the screens also go off. Alt+m, the power popup, boot
# and sleep still lock with the password at once.
soft_lock_min=5
ac_lock_min=120
# Other overrides: ac_off_min= (default 120) hint_min= (logind IdleHint, read by Folding@home's "on idle" toggle, default 5)
