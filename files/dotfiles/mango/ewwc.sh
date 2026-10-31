#!/usr/bin/env sh
# eww client wrapper: `ewwc.sh <eww args...>` == `eww -c ~/.config/mango/eww <args...>`, but it
# first heals the "two daemons" state. eww's client auto-starts a NEW daemon whenever an IPC call
# fails or times out; the old daemon is then orphaned with its windows stuck open and unreachable.
# If more than one daemon is running, kill them all and start a single fresh one.
# (Daemons are found by command line: eww clients share the process name, so counting by name
# would mistake two overlapping client calls for two daemons.)
cfg="$HOME/.config/mango/eww"

daemons() { pgrep -f -x "eww -c $cfg daemon"; }

if [ "$(daemons | wc -l)" -gt 1 ]; then
  kill $(daemons) 2>/dev/null
  sleep 0.5
  kill -9 $(daemons) 2>/dev/null
  setsid -f eww -c "$cfg" daemon >>"$HOME/.cache/mango/eww.log" 2>&1 </dev/null
  sleep 1.5
fi

exec eww -c "$cfg" "$@"
