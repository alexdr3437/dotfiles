#!/usr/bin/env sh
# Switch the desktop theme:  theme.sh <name>     (uses themes/<name>.css)
# Writes into $state_dir (~/.local/state/mango), never into this directory:
#   theme.css         → symlink to themes/<name>.css   (imported by waybar.css, swaync.css, gtklock.css)
#   colors.scss       → the same colours as scss variables (imported by eww/eww.scss)
#   rofi-colors.rasi  → the same colours in rasi syntax  (imported by rofi.rasi)
# then live-reloads waybar, swaync and eww. Themes only define colours; see themes/catppuccin-mocha.css.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

if [ -z "$1" ] || [ ! -f "$dir/themes/$1.css" ]; then
  echo "usage: theme.sh <name>" >&2
  echo "available: $(ls "$dir/themes" | sed 's/\.css$//' | tr '\n' ' ')" >&2
  echo "current:   $(basename "$(readlink "$state_dir/theme.css" 2>/dev/null)" .css)" >&2
  exit 1
fi

ln -sfn "$dir/themes/$1.css" "$state_dir/theme.css"

# eww uses scss variables, not gtk @define-color
sed -n 's/^@define-color \([a-z0-9]*\) *\(#[0-9a-fA-F]*\|@[a-z0-9]*\);.*/$\1: \2;/p' "$state_dir/theme.css" \
  | sed 's/: @/: $/' > "$state_dir/colors.scss"

# rofi reads colours from a generated rasi file (picked up next launch, nothing to reload)
{
  echo "/* generated from theme.css by theme.sh — edit the theme, not this */"
  echo "* {"
  sed -n 's/^@define-color \([a-z0-9]*\) *\(#[0-9a-fA-F]*\|@[a-z0-9]*\);.*/  \1: \2;/p' "$state_dir/theme.css"
  echo "}"
} > "$state_dir/rofi-colors.rasi"

# live reload whatever is running
pkill -USR2 waybar 2>/dev/null
swaync-client -rs >/dev/null 2>&1
# eww can only pick up new colours via a full reload, which rebuilds open windows in a
# random stacking order — so close the popups first; they come back themed on next open
"$dir/popup.sh" close >/dev/null 2>&1
ewwc reload >/dev/null 2>&1
echo "theme: $1"
