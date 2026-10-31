#!/usr/bin/env sh
# Layout picker for the current tag: a rofi dmenu with every layout mango knows, one row
# each with its bar symbol, name and what it does. The current layout is preselected and
# marked active (green in rofi.rasi). Bound to Super+Shift+n in config.conf.
#   layout.sh pick     → open the menu and apply the choice (setlayout on the focused monitor's tag)
#   layout.sh list     → the rows only (what rofi is fed), for tests
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

describe() {   # layout name → one line (unknown layouts still get a row, just without one)
  case "$1" in
    tile) echo "master left, stack right" ;;
    right_tile) echo "master right, stack left" ;;
    center_tile) echo "master centre, stacks both sides" ;;
    vertical_tile) echo "master on top, stack below" ;;
    scroller) echo "scrolling strip of columns" ;;
    vertical_scroller) echo "scrolling strip of rows" ;;
    grid) echo "equal cells, by row" ;;
    vertical_grid) echo "equal cells, by column" ;;
    monocle) echo "one window at a time" ;;
    deck) echo "master left, rest in a pile" ;;
    vertical_deck) echo "master top, rest in a pile" ;;
    dwindle) echo "each new window halves the last" ;;
    fair) echo "evenly shared, columns first" ;;
    vertical_fair) echo "evenly shared, rows first" ;;
    *) echo "" ;;
  esac
}

layouts() { mmsg get layouts | jq -r '.layouts[] | "\(.name)\t\(.symbol)"'; }
current() { mon=$(mmsg get cursorpos | jq -r .monitor); mmsg get monitor "$mon" | jq -r .layout_symbol; }

# rows: "<b>name</b>  <dim>symbol · description</dim>"; names are also plain text so typing filters on them
rows() {
  layouts | while IFS="$(printf '\t')" read -r name sym; do
    desc=$(describe "$name")
    printf '<b>%s</b>  <span alpha="55%%">%s%s</span>\n' "$name" "$sym" "${desc:+ · $desc}"
  done
}

pick() {
  cur=$(current)
  idx=$(layouts | awk -F'\t' -v s="$cur" '$2 == s { print NR - 1; exit }')
  choice=$(rows | rofi -dmenu -i -matching fuzzy -markup-rows -p "layout" -format i \
             ${idx:+-a "$idx" -selected-row "$idx"} \
             -theme "$dir/rofi.rasi" -theme-str 'listview { lines: 14; } window { width: 900px; }') || exit 0
  name=$(layouts | awk -F'\t' -v n="$choice" 'NR - 1 == n { print $1 }')
  [ -n "$name" ] && mmsg dispatch "setlayout,$name" >/dev/null
}

case "$1" in
  pick) pick ;;
  list) rows ;;
  *) usage "pick|list" ;;
esac
