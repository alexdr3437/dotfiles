#!/usr/bin/env sh
# Calendar backend for the eww popup (a hand-built month grid; GTK's calendar can't centre its highlight).
#   cal.sh show [offset]   → build the grid for today's month + offset months and push it to eww (var "cal")
#   cal.sh click DATE      → select DATE (YYYY-MM-DD); a 2nd click on the same day within $dbl ms
#                            opens it in Google Calendar's month view in the default browser
# State (month offset + selection) lives in a file so a click never has to read back from eww:
# one small IPC call per click keeps the daemon responsive.
ewwc="$HOME/.config/mango/ewwc.sh"
dbl=400
run="${XDG_RUNTIME_DIR:-/tmp}"
state="$run/mango-cal-state"     # "<offset> <selected date>"
stamp="$run/mango-cal-click"     # "<date> <ms>" of the last click

build() {   # offset, selected
  ofs=${1:-0}; sel=${2:-}
  today=$(date +%Y-%m-%d)
  first=$(date -d "$(date +%Y-%m-01) $ofs month" +%Y-%m-%d)
  month=$(date -d "$first" +%m)
  title=$(date -d "$first" "+%B %Y")
  dow=$(date -d "$first" +%w)                       # 0 = Sunday → grid starts on Sunday
  start=$(date -d "$first -$dow day" +%Y-%m-%d)
  i=0; dates=""
  while [ $i -lt 42 ]; do
    dates="$dates$(date -d "$start +$i day" +%Y-%m-%d)
"; i=$((i + 1))
  done
  printf '%s' "$dates" | jq -R -s -c --arg m "$month" --arg today "$today" --arg sel "$sel" --arg title "$title" --argjson ofs "$ofs" '
    split("\n") | map(select(length > 0)
      | {date: ., day: (split("-")[2] | tonumber), cur: (split("-")[1] == $m), today: (. == $today), sel: (. == $sel)})
    | {title: $title, ofs: $ofs, sel: $sel, weeks: [range(0; 6) as $w | .[$w * 7 : $w * 7 + 7]]}'
}

push() {   # offset, selected
  echo "$1 $2" > "$state"
  "$ewwc" update "cal=$(build "$1" "$2")"
}

case "$1" in
  show) push "${2:-0}" "" ;;
  click)
    date=${2:?date}
    now=$(date +%s%3N)
    last_date=""; last_time=0
    [ -f "$stamp" ] && read -r last_date last_time < "$stamp"
    echo "$date $now" > "$stamp"
    if [ "$last_date" = "$date" ] && [ $((now - ${last_time:-0})) -lt $dbl ]; then
      rm -f "$stamp"
      y=${date%%-*}; m=${date#*-}; m=${m%-*}; d=${date##*-}
      "$HOME/.config/mango/popup.sh" close
      exec "$HOME/.config/mango/run.sh" xdg-open "https://calendar.google.com/calendar/r/month/$y/${m#0}/${d#0}"
    fi
    ofs=0; [ -f "$state" ] && read -r ofs _ < "$state"
    push "${ofs:-0}" "$date" ;;
  *) echo "usage: cal.sh show [offset] | click YYYY-MM-DD" >&2; exit 1 ;;
esac
