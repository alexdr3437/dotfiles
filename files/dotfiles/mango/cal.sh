#!/usr/bin/env sh
# Calendar backend for the eww popup (a hand-built month grid; GTK's calendar can't centre its highlight).
#   cal.sh show [offset]   → build the grid for today's month + offset months and push it to eww (var "cal")
#   cal.sh click DATE      → select DATE (YYYY-MM-DD); a 2nd click on the same day within $dbl_ms
#                            opens it in Google Calendar's month view in the default browser
# State (month offset | selection | the day it was built for) lives in a file so a click never has
# to read back from eww: one small IPC call per click keeps the daemon responsive. It also lets
# `show 0` skip the rebuild when eww already holds today's month with nothing selected (the
# common case when the popup opens), which is most of the calendar's click-to-popup time.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
cal_state="$runtime_dir/mango-cal-state"   # "<offset>|<selected date>|<built for date>"
stamp="$runtime_dir/mango-cal-click"       # "<date> <ms>" of the last click

build() {   # offset, selected
  ofs=${1:-0}; sel=${2:-}
  today=$(date +%Y-%m-%d)
  first=$(date -d "$(date +%Y-%m-01) $ofs month" +%Y-%m-%d)
  month=${first#*-}; month=${month%-*}
  # shellcheck disable=SC2046  # word-split on purpose: three fields, none with spaces
  set -- $(date -d "$first" "+%w %B %Y")             # weekday of the 1st (0 = Sunday → grid starts on Sunday), title
  dow=$1; title="$2 $3"
  start=$(date -d "$first -$dow day" +%Y-%m-%d)
  # the 42 grid dates are computed in jq (UTC epoch arithmetic, so no DST steps): one
  # process instead of a `date` fork per day, which made the calendar the slowest popup
  jq -nc --arg start "$start" --arg m "$month" --arg today "$today" --arg sel "$sel" --arg title "$title" --argjson ofs "$ofs" '
    ($start | strptime("%Y-%m-%d") | mktime) as $t0
    | [range(0; 42) | ($t0 + . * 86400) | strftime("%Y-%m-%d")
        | {date: ., day: (split("-")[2] | tonumber), cur: (split("-")[1] == $m), today: (. == $today), sel: (. == $sel)}]
    | {title: $title, ofs: $ofs, sel: $sel, weeks: [range(0; 6) as $w | .[$w * 7 : $w * 7 + 7]]}'
}

push() {   # offset, selected
  echo "$1|$2|$(date +%Y-%m-%d)" > "$cal_state"
  refresh cal "$(build "$1" "$2")"
}

case "$1" in
  show)
    # already showing month $ofs of today with no selection → nothing to do. Only trusted
    # while the daemon that received it is still the one running: a fresh daemon starts from
    # the empty defvar, so the state file must be newer than the daemon's socket.
    ofs=${2:-0}
    set -- "$runtime_dir"/eww-server_*
    # shellcheck disable=SC3013  # -nt: fine in dash and bash, saves a stat fork per click
    [ "$cal_state" -nt "$1" ] && [ "$(cat "$cal_state" 2>/dev/null)" = "$ofs||$(date +%Y-%m-%d)" ] && exit 0
    push "$ofs" "" ;;
  click)
    date=${2:?date}
    now=$(now_ms)
    last_date=""; last_time=0
    [ -f "$stamp" ] && read -r last_date last_time < "$stamp"
    echo "$date $now" > "$stamp"
    if [ "$last_date" = "$date" ] && [ $((now - ${last_time:-0})) -lt "$dbl_ms" ]; then
      rm -f "$stamp"
      y=${date%%-*}; m=${date#*-}; m=${m%-*}; d=${date##*-}
      "$dir/popup.sh" close
      exec "$dir/run.sh" xdg-open "https://calendar.google.com/calendar/r/month/$y/${m#0}/${d#0}"
    fi
    ofs=0; [ -f "$cal_state" ] && { read -r state < "$cal_state"; ofs=${state%%|*}; }
    push "${ofs:-0}" "$date" ;;
  *) usage "show [offset] | click YYYY-MM-DD" ;;
esac
