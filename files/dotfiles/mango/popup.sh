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
close_others()    { close_ids "$(open_wins | grep -v '^backdrop-' | grep -vx "$win")"; }
open_backdrops() {
  mons=$("$dir/monitors.sh" names)   # enabled only: a disabled monitor has no screen for eww
  for bmon in ${mons:-0}; do   # (not "mon": that holds the popup's target monitor)
    ewwc open backdrop --screen "$bmon" --id "backdrop-$bmon" >/dev/null 2>&1
  done
}

case "$win" in
  close) close_all; swaync-client -cp >/dev/null 2>&1; exit 0 ;;
  notifications) close_all; exec swaync-client -t -sw ;;
esac
swaync-client -cp >/dev/null 2>&1   # close the notification panel if it's open

now=$(now_ms)
if [ -n "$app" ]; then
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

# monitor under the pointer: cursorpos gives x/y plus the *focused* monitor (not the pointer's),
# so match the coordinates against the monitor layout; falls back to monitor 0
mon=$(mmsg get cursorpos 2>/dev/null | jq -r --argjson mons "$(mmsg get all-monitors 2>/dev/null | jq -c .monitors)" '
  .x as $x | .y as $y | ([$mons[] | select($x >= .x and $x < .x + .width and $y >= .y and $y < .y + .height) | .name] | first) // .monitor' 2>/dev/null)

close_others

# did a double-click (2nd click) arrive while we were working? (marker younger than 1s)
cancelled() {
  [ -f "$cancel" ] || return 1
  age=$(( $(now_ms) - $(cat "$cancel" 2>/dev/null || echo 0) ))
  rm -f "$cancel"
  [ "$age" -lt 1000 ]
}

[ "$win" = calendar ] && "$dir/cal.sh" show 0                   # fresh month grid each time (slow-ish)
cancelled && { close_backdrops; exit 0; }                       # checked as late as possible…
open_backdrops   # before the popup, so the popup stacks above it
ewwc open --toggle ${mon:+--screen "$mon"} "$win"
cancelled && { close_ids "$win"; close_backdrops; exit 0; }     # …and once more after opening
# toggled closed rather than open → no popup left, drop the backdrop too
ewwc active-windows 2>/dev/null | grep -q "^$win:" || close_backdrops
