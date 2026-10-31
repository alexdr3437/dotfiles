#!/usr/bin/env sh
# Switch the desktop theme:  theme.sh <name>     (uses themes/<name>.css)
# Relinks theme.css, regenerates eww's colour file and live-reloads
# waybar, swaync and eww. Themes only define colours; see themes/catppuccin-mocha.css.
dir=$(dirname "$(readlink -f "$0")")

if [ -z "$1" ] || [ ! -f "$dir/themes/$1.css" ]; then
  echo "usage: theme.sh <name>" >&2
  echo "available: $(ls "$dir/themes" | sed 's/\.css$//' | tr '\n' ' ')" >&2
  echo "current:   $(readlink "$dir/theme.css" | sed 's|themes/||; s/\.css$//')" >&2
  exit 1
fi

ln -sfn "themes/$1.css" "$dir/theme.css"

# eww uses scss variables, not gtk @define-color
mkdir -p "$dir/eww"
sed -n 's/^@define-color \([a-z0-9]*\) *\(#[0-9a-fA-F]*\|@[a-z0-9]*\);.*/$\1: \2;/p' "$dir/theme.css" \
  | sed 's/: @/: $/' > "$dir/eww/_colors.scss"

# rofi reads colours from a generated rasi file (picked up next launch, nothing to reload)
{
  echo "/* generated from theme.css by theme.sh — edit the theme, not this */"
  echo "* {"
  sed -n 's/^@define-color \([a-z0-9]*\) *\(#[0-9a-fA-F]*\|@[a-z0-9]*\);.*/  \1: \2;/p' "$dir/theme.css"
  echo "}"
} > "$dir/rofi-colors.rasi"

# live reload whatever is running
pkill -USR2 waybar 2>/dev/null
swaync-client -rs >/dev/null 2>&1
# eww can only pick up new colours via a full reload, which rebuilds open windows in a
# random stacking order — so close the popups first; they come back themed on next open
"$dir/popup.sh" close >/dev/null 2>&1
"$dir/ewwc.sh" reload >/dev/null 2>&1
echo "theme: $1"
