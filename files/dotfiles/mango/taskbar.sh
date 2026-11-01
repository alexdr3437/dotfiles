#!/usr/bin/env sh
# Grouped taskbar backend (bottom bar): one icon per app per monitor, badge with the window count,
# then a dimmed section with that monitor's minimized windows (one icon each, not grouped).
#   taskbar.sh status             → eww JSON { "<monitor>": { apps: [{app, icon, count, focused, urgent, title, ids}],
#                                                             min:  [{app, icon, title, id}] } }
#   taskbar.sh cycle MON APP      → focus the next window of that app on that monitor (wraps; jumps to its tag)
#   taskbar.sh close MON APP      → close the focused window of that app (or its first one)
#   taskbar.sh restore ID         → un-minimize one window onto the current tag and focus it
#   taskbar.sh kill ID...         → close windows by id (middle-click in the minimized section, menu "Quit")
#   taskbar.sh menu MON app APP   → right-click menu above the pointer for an app group on MON
#   taskbar.sh menu MON min ID    →   … or for one minimized window. Fills the eww var taskmenu:
#                                   {kind, title, ids (space-separated), count, cur, maxed}
#   taskbar.sh minimize ID...     → minimize windows by id
#   taskbar.sh maximize ID        → toggle mango's maximize on one window and focus it
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
    .clients
    | group_by(.monitor)
    | map({(.[0].monitor): {
        apps: ([.[] | select(.is_scratchpad | not)]     # a minimized window is also is_scratchpad (set_minimized)
               | group_by(.appid) | map(sort_by(.id)) | sort_by(.[0].id)
               | map({app: .[0].appid, icon: ($icons[.[0].appid] // .[0].appid), count: length,
                      focused: any(.[]; .is_focused), urgent: any(.[]; .is_urgent),
                      title: ((map(select(.is_focused)) | first // .[0]) | .title), ids: map(.id)})),
        min: ([.[] | select(.is_minimized and (.is_namedscratchpad | not))] | sort_by(.id)   # same set restore_minimized walks
              | map({app: .appid, icon: ($icons[.appid] // .appid), title, id}))}})
    | add // {}'
}

pick() {   # mode(next|current) MON APP → client id
  mmsg get all-clients | jq -r --arg m "$2" --arg a "$3" --arg mode "$1" '
    ([.clients[] | select(.monitor == $m and .appid == $a and (.is_scratchpad | not) and (.is_minimized | not))] | sort_by(.id) | map(.id)) as $ids
    | ([.clients[] | select(.is_focused) | .id] | first) as $cur
    | if ($ids | length) == 0 then empty
      elif $mode == "current" then (if ($ids | index($cur)) != null then $cur else $ids[0] end)
      else (($ids | index($cur)) as $i | if $i == null then $ids[0] else $ids[($i + 1) % ($ids | length)] end) end'
}

menu() {   # MON KIND KEY
  mon=$1
  "$dir/popup.sh" close   # one popup or menu at a time
  clients=$(mmsg get all-clients) || exit 0
  target=$(printf '%s' "$clients" | jq -c --arg m "$1" --arg kind "$2" --arg key "$3" '
    if $kind == "min" then
      .clients[] | select(.id == ($key | tonumber))
      | {kind: "min", title, ids: (.id | tostring), count: 1, cur: .id, maxed: false}
    else
      [.clients[] | select(.monitor == $m and .appid == $key and (.is_scratchpad | not))] | sort_by(.id)
      | select(length > 0) as $w
      | ((map(select(.is_focused)) | first) // $w[0]) as $c   # the window cycle/close would act on
      | {kind: "app", title: $c.title, ids: ($w | map(.id | tostring) | join(" ")), count: ($w | length),
         cur: $c.id, maxed: $c.is_maximized}
    end')
  [ -n "$target" ] || exit 0
  # menu (190px wide) centred on the pointer, kept 8px inside the monitor; plus the enabled
  # monitors, which each get a click-outside backdrop like popup.sh's popups
  # shellcheck disable=SC2046  # word-split on purpose: monitor names have no spaces
  set -- $(jq -rn --argjson c "$(mmsg get cursorpos)" --argjson ms "$(mmsg get all-monitors)" --arg m "$1" '
    ($ms.monitors[] | select(.name == $m)) as $o
    | ([[($c.x - $o.x - 95 | floor), $o.width - 198] | min, 8] | max),
      ($ms.monitors[] | select(.width > 0) | .name)')
  x=${1:-8}; [ $# -gt 0 ] && shift
  refresh taskmenu "$target"
  args=""
  for b in "$@"; do args="$args backdrop:backdrop-$b --arg backdrop-$b:mon=$b"; done
  # shellcheck disable=SC2086  # names and args have no spaces
  ewwc open-many $args taskmenu --arg "taskmenu:mon=$mon" --arg "taskmenu:x=$x" >/dev/null 2>&1
}

case "$1" in
  status) status ;;
  menu) menu "$2" "$3" "$4" ;;
  minimize) shift; for id; do mmsg dispatch minimized "client,$id" >/dev/null; done; sleep 0.2; refresh taskbar "$(status)" ;;
  maximize) mmsg dispatch focusid "client,$2" >/dev/null; mmsg dispatch togglemaximizescreen "client,$2" >/dev/null; sleep 0.2; refresh taskbar "$(status)" ;;
  cycle) id=$(pick next "$2" "$3"); [ -n "$id" ] && mmsg dispatch focusid "client,$id" >/dev/null; sleep 0.2; refresh taskbar "$(status)" ;;
  close) id=$(pick current "$2" "$3"); [ -n "$id" ] && mmsg dispatch killclient "client,$id" >/dev/null; sleep 0.3; refresh taskbar "$(status)" ;;
  # a minimized window is a hidden scratchpad to mango: focusid shows it as a floating scratchpad (client_active),
  # then restore_minimized evicts that shown scratchpad onto the current tag as a tiled window (what Super+Shift+i does)
  restore) mmsg dispatch focusid "client,$2" >/dev/null; mmsg dispatch restore_minimized >/dev/null; sleep 0.2; refresh taskbar "$(status)" ;;
  kill) shift; for id; do mmsg dispatch killclient "client,$id" >/dev/null; done; sleep 0.3; refresh taskbar "$(status)" ;;
  *) usage "status|cycle MON APP|close MON APP|restore ID|kill ID...|menu MON app APP|menu MON min ID|minimize ID...|maximize ID" ;;
esac
