#!/usr/bin/env sh
# Action history backend (reads the log written by run.sh).
#   history.sh status      → eww JSON [{t, cmd, rc, out, file}] newest first (last 30)
#   history.sh open FILE   → show a command's full output in the editor (ghostty + $EDITOR)
#   history.sh clear
log="$HOME/.cache/mango/actions.log"
outdir="$HOME/.cache/mango/actions"
ewwc="$HOME/.config/mango/ewwc.sh"

status() {
  [ -s "$log" ] || { echo "[]"; return; }
  tac "$log" | head -30 | jq -R -s -c '
    split("\n") | map(select(length > 0) | split("\t")
      | {t: (.[0] | tonumber | strflocaltime("%-I:%M:%S %p")),
         cmd: (.[1] | gsub("/home/[^/]+/.config/mango/"; "")),
         rc: (.[2] | tonumber), out: (.[3] // ""), file: (.[4] // "")})'
}

case "$1" in
  status) status ;;
  open)
    "$ewwc" close history >/dev/null 2>&1
    f=${2:-}; [ -s "$f" ] || f=$log
    exec ghostty --title="history: $(basename "$f")" -e "${EDITOR:-nvim}" -R "$f" ;;
  clear) : > "$log"; rm -f "$outdir"/*.log; "$ewwc" update "history=[]" >/dev/null 2>&1 ;;
  *) echo "usage: history.sh status|open FILE|clear" >&2; exit 1 ;;
esac
