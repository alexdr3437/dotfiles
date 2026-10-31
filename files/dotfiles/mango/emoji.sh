#!/usr/bin/env sh
# Emoji picker (Super+period): rofimoji in the mango rofi theme; the pick is typed into the
# focused window (wtype) and copied. The recent emojis rofimoji shows as "1: … 2: …" are
# picked with rofi's custom keys, Alt+1… by default, which mango takes for tags before rofi
# sees them; they are moved to Super+1…Super+0 (free in config.conf), and rofi's own
# Super+N bindings (kb-select-N: jump to row N) are cleared to make room.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

keys=""
for n in 1 2 3 4 5 6 7 8 9 10; do
  keys="$keys -kb-select-$n '' -kb-custom-$n Super+$((n % 10))"   # the 10th is Super+0
done
exec rofimoji --action type copy --skin-tone neutral --selector rofi \
  --selector-args "-theme $dir/rofi.rasi $keys"
