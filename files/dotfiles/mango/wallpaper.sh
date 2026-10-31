#!/usr/bin/env sh
# Set a random wallpaper from ~/Pictures/backgrounds, and build the lock screen
# background from it: a blurred, dimmed copy at ~/.cache/mango/lock.png (lock.sh).
cache="$HOME/.cache/mango"
mkdir -p "$cache"

img=$(find "$HOME/Pictures/backgrounds" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n 1)
[ -n "$img" ] || exit 0

pkill -f '^swaybg '  # nix wraps binaries, so pkill -x swaybg never matches
setsid -f swaybg -i "$img" -m fill >/dev/null 2>&1 </dev/null
printf '%s\n' "$img" > "$cache/wallpaper"   # what is on screen now

# blur at 480px wide and scale back up: same look as blurring at 1080p, ~1s instead of ~7s
if command -v magick >/dev/null; then
  magick "$img" -resize 480x270^ -blur 0x4 -resize 1920x1080^ -fill black -colorize 35% "$cache/lock.tmp.png" \
    && mv "$cache/lock.tmp.png" "$cache/lock.png"
fi
