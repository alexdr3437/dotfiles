#!/usr/bin/env sh
# Now-playing backend over MPRIS D-Bus (busctl), so no playerctl needed.
#   media.sh status → eww JSON {player, status, title, artist, art, length, pos, pct}
#   media.sh playpause | next | prev
ewwc="$HOME/.config/mango/ewwc.sh"
artdir="$HOME/.cache/mango/art"
empty='{"player":"","status":"","title":"","artist":"","art":"","length":0,"pos":0,"pct":0}'

players() { busctl --user list --json=short 2>/dev/null | jq -r '.[].name | select(startswith("org.mpris.MediaPlayer2."))'; }
prop() { busctl --user --json=short get-property "$1" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player "$2" 2>/dev/null | jq -c '.data'; }

# prefer a playing player, else the first one
pick() {
  first=""
  for p in $(players); do
    [ -z "$first" ] && first=$p
    [ "$(prop "$p" PlaybackStatus)" = '"Playing"' ] && { echo "$p"; return; }
  done
  echo "$first"
}

status() {
  p=$(pick)
  [ -n "$p" ] || { echo "$empty"; return; }
  meta=$(prop "$p" Metadata); [ -n "$meta" ] || meta='{}'
  pos=$(prop "$p" Position); [ -n "$pos" ] || pos=0
  st=$(prop "$p" PlaybackStatus | jq -r .)
  art=$(printf '%s' "$meta" | jq -r '."mpris:artUrl".data // ""')
  case "$art" in
    http*) mkdir -p "$artdir"; f="$artdir/$(printf '%s' "$art" | md5sum | cut -c1-32).img"
           [ -s "$f" ] || curl -sf --max-time 5 -o "$f" "$art"; art=$f ;;
    file://*) art=${art#file://} ;;
  esac
  jq -cn --argjson m "$meta" --arg st "$st" --arg p "$p" --argjson pos "$pos" --arg art "$art" '
    {player: ($p | sub("org.mpris.MediaPlayer2."; "") | split(".")[0]), status: $st,
     title: ($m."xesam:title".data // ""), artist: (($m."xesam:artist".data // []) | join(", ")),
     art: $art, length: ((($m."mpris:length".data // 0) / 1000000) | floor), pos: (($pos / 1000000) | floor)}
    | .pct = (if .length > 0 then ((.pos * 100 / .length) | floor) else 0 end)'
}

refresh() { "$ewwc" update "media=$(status)" >/dev/null 2>&1; }
call() { p=$(pick); [ -n "$p" ] && "$HOME/.config/mango/run.sh" busctl --user call "$p" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player "$1" >/dev/null 2>&1; sleep 0.3; refresh; }

bar_json() {   # waybar JSON from a status JSON on stdin; empty text hides the module
  jq -c '(if .player == "spotify" then "󰓇" elif .player == "firefox" then "󰈹" else "󰎆" end) as $pi
    | if .player == "" then {text: "", class: "none", tooltip: "nothing playing"}
      else {text: ((if .status == "Playing" then $pi else "󰏤" end) + "  " + ((.title + (if .artist != "" then " · " + .artist else "" end)) | .[0:48])),
            tooltip: "\(.title)\n\(.artist)\n\(.player) · \(.status)", class: (.status | ascii_downcase)} end'
}

case "$1" in
  status) status ;;
  bar) status | bar_json ;;
  bar-stream) while :; do status | bar_json; sleep 1; done ;;
  playpause) call PlayPause ;;
  next) call Next ;;
  prev) call Previous ;;
  *) echo "usage: media.sh status|playpause|next|prev" >&2; exit 1 ;;
esac
