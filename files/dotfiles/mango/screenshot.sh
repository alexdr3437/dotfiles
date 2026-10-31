#!/usr/bin/env sh
# Screenshot a region: slurp to drag the area (Escape cancels, nothing is taken),
# grim grabs it, satty opens it to annotate. In satty Enter copies to the clipboard
# and closes, Ctrl+S saves to $screenshot_dir (~/Pictures/Screenshots unless
# hosts/<host>/env.sh says otherwise). Bound to Super+t in config.conf.
# Replaces spectacle, whose region picker needs KWin.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
out="${screenshot_dir:-$HOME/Pictures/Screenshots}"
mkdir -p "$out"

geom=$(slurp -d) || exit 0
grim -g "$geom" - | satty --filename - \
  --copy-command wl-copy \
  --output-filename "$out/%Y-%m-%d_%H-%M-%S.png" \
  --early-exit
