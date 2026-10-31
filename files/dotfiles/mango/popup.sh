#!/usr/bin/env sh
# popup.sh <window> [app]      |      popup.sh close
#   click        → toggle the eww popup on the monitor the pointer is on (closing other popups)
#   double-click → close the popup and launch <app> instead (waybar has no double-click
#                  event, so a 2nd click within $dbl_ms of the 1st counts as one)
#   close        → close every popup (what the click-outside backdrop runs)
# Windows: the defwindows in eww/eww.yuck, plus "notifications" (the swaync panel, treated
# like a popup so everything closes everything else).
# While a popup is open an invisible "backdrop" eww window covers each monitor below the
# bars; clicking it closes everything.
# This script's run time is the click-to-popup delay, so the path to the popup is kept short:
# the compositor (mmsg) and eww (active-windows) are queried in parallel, one jq reads both
# answers, the window list is parsed in the shell without forks, and a single open-many
# creates the missing backdrops plus the popup. open-many has no --screen, so every popup
# window takes a `mon` argument instead (eww.yuck). Each fork costs ~5 ms here and each eww
# or mmsg round trip ~10-25 ms; the whole click lands around 100 ms.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
all="calendar power bluetooth wifi volume battery system settings weather media proton tailscale history"
win=${1:?usage: popup.sh <$(echo "$all" | tr ' ' '|')|notifications|close> [app]}
app=$2
stamp="$runtime_dir/mango-popup-$win"   # time of the last click (ms)
cancel="$stamp.dbl"                     # exists while a double-click is being handled

# only close what is actually open: one eww call, no "no such window" noise
open_wins() { ewwc active-windows 2>/dev/null | cut -d: -f1 | grep -v "^taskbar-"; }   # taskbar windows are not popups
# shellcheck disable=SC2086  # $1 is a whitespace-separated list of window ids
close_ids() { [ -n "$1" ] && ewwc close $1 >/dev/null 2>&1; }
close_backdrops() { close_ids "$(open_wins | grep '^backdrop-')"; }
close_all()       { close_ids "$(open_wins)"; }

case "$win" in
  close) close_all; swaync-client -cp >/dev/null 2>&1; exit 0 ;;
  notifications) close_all; exec swaync-client -t -sw ;;
esac
swaync-client -cp >/dev/null 2>&1 &   # close the notification panel if it's open (not waited for)

if [ -n "$app" ]; then
  now=$(now_ms)
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  echo "$now" > "$stamp"
  if [ $((now - last)) -lt "$dbl_ms" ]; then
    # 2nd click: tell the still-running 1st click not to open, close if it already did
    echo "$now" > "$cancel"
    ewwc close "$win" >/dev/null 2>&1
    close_backdrops
    exec sh -c "$app >/dev/null 2>&1 &"
  fi
fi

# in parallel: what eww has open, the monitor layout, the pointer. Each is an independent
# round trip of 10-25 ms.
tmp="$runtime_dir/mango-popup-$$"
ewwc active-windows >"$tmp.wins" 2>/dev/null & p1=$!
mmsg get all-monitors >"$tmp.mons" 2>/dev/null & p2=$!
mmsg get cursorpos >"$tmp.cur" 2>/dev/null
wait "$p1" "$p2"

# one jq: first the monitor under the pointer, then the enabled monitors (width > 0; a
# disabled one has no screen for eww), which get a backdrop each. cursorpos gives x/y plus
# the *focused* monitor (not the pointer's), so match the coordinates against the layout;
# falls back to monitor 0
# shellcheck disable=SC2046  # word-split on purpose: monitor names have no spaces
set -- $(jq -rn --slurpfile m "$tmp.mons" --slurpfile c "$tmp.cur" '
  ($m[0].monitors // []) as $mons | ($c[0] // {}) as $cur
  | (([$mons[] | select($cur.x >= .x and $cur.x < .x + .width and $cur.y >= .y and $cur.y < .y + .height) | .name] | first)
     // $cur.monitor // 0),
    ($mons[] | select(.width > 0) | .name)' 2>/dev/null)
mon=${1:-0}; [ $# -gt 0 ] && shift; mons=${*:-0}

# the open windows ("id: name" per line), sorted without forking
others=""; backdrops=""; is_open=0
while IFS= read -r line; do
  id=${line%%:*}
  case "$id" in
    taskbar-*) ;;                           # not popups
    backdrop-*) backdrops="$backdrops $id" ;;
    "$win") is_open=1 ;;
    *) others="$others $id" ;;
  esac
done <"$tmp.wins"
rm -f "$tmp.wins" "$tmp.mons" "$tmp.cur" &   # not waited for

close_ids "$others"
# toggle: already open → close it and the backdrops, done
if [ "$is_open" = 1 ]; then close_ids "$win $backdrops"; exit 0; fi

# did a double-click (2nd click) arrive while we were working? (marker younger than 1s)
cancelled() {
  [ -f "$cancel" ] || return 1
  age=$(( $(now_ms) - $(cat "$cancel" 2>/dev/null || echo 0) ))
  rm -f "$cancel"
  [ "$age" -lt 1000 ]
}

[ "$win" = calendar ] && "$dir/cal.sh" show 0                   # fresh month grid (skipped when unchanged)
cancelled && { close_ids "$backdrops"; exit 0; }                  # checked as late as possible…

# backdrops first so the popup stacks above them (same layer, creation order); the ones
# already open (another popup was showing) are left alone
set --
for bmon in $mons; do
  case " $backdrops " in
    *" backdrop-$bmon "*) ;;
    *) set -- "$@" "backdrop:backdrop-$bmon" --arg "backdrop-$bmon:mon=$bmon" ;;
  esac
done
ewwc open-many "$@" "$win" --arg "$win:mon=$mon" >/dev/null 2>&1
cancelled && { close_ids "$win"; close_backdrops; exit 0; }     # …and once more after opening
