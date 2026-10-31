#!/usr/bin/env sh
# App launcher (Super+r): rofi over the .desktop entries, usage-sorted, three ways to launch.
#   launcher.sh pick  → the menu. Enter launches; Shift+Enter launches ephemeral (floating,
#                       stashed to the scratchpad when it loses focus: ephemeral.sh --stash);
#                       Ctrl+t launches in ghostty. Only the ephemeral launch of a terminal entry
#                       passes --confirm-close-surface=false (its automatic close must not prompt);
#                       the bar's double-click apps in waybar.jsonc do the same
#   launcher.sh list  → id · name · icon · exec · terminal · search text, usage-sorted (tests)
#   launcher.sh rows  → what rofi is fed
# A dmenu-mode replacement for `rofi -show drun`: drun treats Shift+Enter like Enter and has
# no per-key hook, dmenu mode reports the key as the exit code (0 Enter, 10/11 custom keys).
# Entries: ~/.local/share/applications first, then XDG_DATA_DIRS in order; first id wins.
# NoDisplay / Hidden / OnlyShowIn entries are skipped. Usage counts in $cache_dir/launcher.tsv.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
tab="$(printf '\t')"
usage_file="$cache_dir/launcher.tsv"

dirs() {
  echo "$HOME/.local/share/applications"
  printf '%s\n' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' '\n' | sed 's|$|/applications|'
}

# one pass over every .desktop file: id TAB name TAB icon TAB exec TAB terminal TAB search text
entries() {
  dirs | while read -r d; do [ -d "$d" ] && find "$d" -maxdepth 1 -name '*.desktop' -print0; done 2>/dev/null \
  | xargs -0 -r awk -F= '
    function flush() {
      if (name == "" || exec == "" || skip || (type != "" && type != "Application")) return
      if (id in seen) return
      seen[id] = 1
      gsub(/%[fFuUdDnNickvm]/, "", exec); gsub(/%%/, "%", exec); gsub(/ +$/, "", exec)
      printf "%s\t%s\t%s\t%s\t%s\t%s %s %s\n", id, name, icon, exec, (term == "true" ? 1 : 0), generic, comment, keywords
    }
    FNR == 1 { flush(); n = split(FILENAME, p, "/"); id = p[n]; name = icon = exec = type = term = generic = comment = keywords = ""; skip = 0; in_entry = 0 }
    /^\[Desktop Entry\]/ { in_entry = 1; next }
    /^\[/ { in_entry = 0; next }
    !in_entry { next }
    { v = substr($0, index($0, "=") + 1) }
    $1 == "Name" { name = v }
    $1 == "Icon" { icon = v }
    $1 == "Exec" { exec = v }
    $1 == "Type" { type = v }
    $1 == "Terminal" { term = v }
    $1 == "GenericName" { generic = v }
    $1 == "Comment" { comment = v }
    $1 == "Keywords" { keywords = v; gsub(/;/, " ", keywords) }
    $1 == "NoDisplay" && v == "true" { skip = 1 }
    $1 == "Hidden" && v == "true" { skip = 1 }
    $1 == "OnlyShowIn" { skip = 1 }
    END { flush() }'
}

# entries, most used first, then by name
list() {
  entries | awk -F'\t' -v OFS='\t' -v f="$usage_file" '
    BEGIN { while ((getline l < f) > 0) { split(l, a, "\t"); n[a[1]] = a[2] } }
    { print (n[$1] ? n[$1] : 0), $0 }' \
  | LC_ALL=C sort -t "$tab" -k1,1nr -k3,3f | cut -f2-
}

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# rofi rows: shown column = name, hidden column = search text (id, generic name, comment,
# keywords); the icon rides along as a row option
rows() {
  list | while IFS="$tab" read -r id name icon _ _ text; do
    printf '%s\t%s %s\0icon\037%s\n' "$(printf '%s' "$name" | esc)" "$(printf '%s' "$text" | esc)" "${id%.desktop}" "$icon"
  done
}

bump() {   # usage count for id
  { grep -v "^$1$tab" "$usage_file" 2>/dev/null; printf '%s\t%s\n' "$1" "$(( $(grep "^$1$tab" "$usage_file" 2>/dev/null | cut -f2) + 1 ))"; } > "$usage_file.new"
  mv "$usage_file.new" "$usage_file"
}

pick() {
  idx=$(rows | rofi -dmenu -i -matching fuzzy -sort -sorting-method fzf -show-icons -p "󰀻" -format i \
          -display-columns 1 -display-column-separator "$tab" \
          -kb-accept-alt "" -kb-custom-1 "Shift+Return" -kb-custom-2 "Control+t" \
          -theme "$dir/rofi.rasi")
  rc=$?
  case "$rc" in 0|10|11) ;; *) exit 0 ;; esac
  line=$(list | sed -n "$((idx + 1))p"); [ -n "$line" ] || exit 0
  IFS="$tab" read -r id _ _ exec term _ <<EOF
$line
EOF
  bump "$id"
  # terminal entries (and Ctrl+t) run inside ghostty; only the ephemeral launch gets
  # --confirm-close-surface=false, so its automatic close never prompts. A terminal you
  # opened to keep still asks before closing a running program.
  quoted="'$(printf '%s' "$exec" | sed "s/'/'\\\\''/g")'"
  case "$rc" in
    0)  [ "$term" = 1 ] && exec="ghostty -e sh -c $quoted"
        setsid -f sh -c "$exec" >/dev/null 2>&1 </dev/null ;;
    10) [ "$term" = 1 ] && exec="ghostty --confirm-close-surface=false -e sh -c $quoted"
        "$dir/async.sh" "$dir/ephemeral.sh" run --stash sh -c "$exec" ;;
    11) setsid -f ghostty -e sh -c "$exec" >/dev/null 2>&1 </dev/null ;;
  esac
}

case "$1" in
  pick) pick ;;
  list) list ;;
  rows) rows ;;
  *) usage "pick | list | rows" ;;
esac
