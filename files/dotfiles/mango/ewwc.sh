#!/usr/bin/env sh
# eww client wrapper: `ewwc.sh <eww args...>` == `eww -c ~/.config/mango/eww --no-daemonize <args...>`.
# Without --no-daemonize eww's client auto-starts a NEW daemon whenever an IPC call fails or
# times out; the old daemon is then orphaned with its windows stuck open and unreachable (the
# "two daemons" state). With the flag a failed call just fails, and only then are the daemons
# looked at: none → start one; more than one → kill them all and start a fresh one; then retry
# once. The pgrep scan costs ~50 ms, so it stays off the happy path: popup.sh makes two or three
# of these calls per click and the sum is the click-to-popup delay.
# (Daemons are found by command line: eww clients share the process name, so counting by name
# would mistake two overlapping client calls for two daemons.)
# Scripts call eww through the ewwc() wrapper in lib.sh, which calls eww directly and runs this
# script only when that fails, so the happy path never pays for a second shell start.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
cfg="$dir/eww"

if eww -c "$cfg" --no-daemonize "$@"; then exit 0; else rc=$?; fi

daemons() { pgrep -f -x "eww -c $cfg daemon"; }
n=$(daemons | wc -l)
[ "$n" -eq 1 ] && exit "$rc"   # one healthy daemon: a real error (no such window, ...), pass it on
if [ "$n" -gt 1 ]; then
  # shellcheck disable=SC2046  # pid list
  kill $(daemons) 2>/dev/null
  sleep 0.5
  # shellcheck disable=SC2046
  kill -9 $(daemons) 2>/dev/null
fi
setsid -f eww -c "$cfg" daemon >>"$cache_dir/eww.log" 2>&1 </dev/null
sleep 1.5
exec eww -c "$cfg" --no-daemonize "$@"
