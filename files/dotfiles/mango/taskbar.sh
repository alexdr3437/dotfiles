#!/usr/bin/env sh
# Grouped taskbar backend (bottom bar): one icon per app per monitor, badge with the window count.
#   taskbar.sh status             → eww JSON { "<monitor>": [{app, icon, count, focused, urgent, title, ids}] }
#   taskbar.sh cycle MON APP      → focus the next window of that app on that monitor (wraps; jumps to its tag)
#   taskbar.sh close MON APP      → close the focused window of that app (or its first one)
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
icons="$cache_dir/icons.tsv"   # appid TAB icon name, learned from .desktop files (only hits are cached)

icon_for() {
  hit=$(awk -F'\t' -v a="$1" '$1 == a { print $2; exit }' "$icons" 2>/dev/null)
  [ -n "$hit" ] && { echo "$hit"; return; }
  icon=""; lower=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  dirs=$(printf '%s:%s' "${XDG_DATA_DIRS:-/usr/share}" "$HOME/.local/share" | tr ':' ' ')
  for d in $dirs; do
    for f in "$d/applications/$1.desktop" "$d/applications/$lower.desktop"; do
      [ -f "$f" ] && { icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-); break 2; }
    done
  done
  if [ -z "$icon" ]; then   # slower: match StartupWMClass
    for d in $dirs; do
      f=$(grep -lisF "StartupWMClass=$1" "$d"/applications/*.desktop 2>/dev/null | head -1)
      [ -n "$f" ] && { icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-); break; }
    done
  fi
  if [ -n "$icon" ]; then
    printf '%s\t%s\n' "$1" "$icon" >> "$icons"
  else
    icon=$1   # let GTK try the app id itself; not cached, so an app installed later is picked up
  fi
  echo "$icon"
}

status() {
  clients=$(mmsg get all-clients 2>/dev/null) || { echo "{}"; return; }
  icon_map=$(printf '%s' "$clients" | jq -r '[.clients[].appid] | unique[]' | while read -r a; do
    [ -n "$a" ] && printf '%s\t%s\n' "$a" "$(icon_for "$a")"
  done | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}')
  printf '%s' "$clients" | jq -c --argjson icons "$icon_map" '
    [.clients[] | select(.is_scratchpad | not)]
    | group_by(.monitor)
    | map({(.[0].monitor):
        (group_by(.appid) | map(sort_by(.id)) | sort_by(.[0].id)
         | map({app: .[0].appid, icon: ($icons[.[0].appid] // .[0].appid), count: length,
                focused: any(.[]; .is_focused), urgent: any(.[]; .is_urgent),
                title: ((map(select(.is_focused)) | first // .[0]) | .title), ids: map(.id)}))})
    | add // {}'
}

pick() {   # mode(next|current) MON APP → client id
  mmsg get all-clients | jq -r --arg m "$2" --arg a "$3" --arg mode "$1" '
    ([.clients[] | select(.monitor == $m and .appid == $a and (.is_scratchpad | not))] | sort_by(.id) | map(.id)) as $ids
    | ([.clients[] | select(.is_focused) | .id] | first) as $cur
    | if ($ids | length) == 0 then empty
      elif $mode == "current" then (if ($ids | index($cur)) != null then $cur else $ids[0] end)
      else (($ids | index($cur)) as $i | if $i == null then $ids[0] else $ids[($i + 1) % ($ids | length)] end) end'
}

case "$1" in
  status) status ;;
  cycle) id=$(pick next "$2" "$3"); [ -n "$id" ] && mmsg dispatch focusid "client,$id" >/dev/null; sleep 0.2; refresh taskbar "$(status)" ;;
  close) id=$(pick current "$2" "$3"); [ -n "$id" ] && mmsg dispatch killclient "client,$id" >/dev/null; sleep 0.3; refresh taskbar "$(status)" ;;
  *) usage "status|cycle MON APP|close MON APP" ;;
esac
