#!/usr/bin/env sh
# Volume backend for the eww popup (pipewire via pactl/wpctl).
#   vol.sh status             → JSON {volume, muted, name, sinks:[{name,desc,default}]}
#   vol.sh set N | mute | sink NAME
#   vol.sh up | down          → hardware volume keys (config.conf), $step % at a time, capped at 100
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
step=5

status() {
  default=$(pactl get-default-sink)
  pactl -f json list sinks | jq -c --arg d "$default" '
    map({name, desc: .description, mute, default: (.name == $d),
         vol: (.volume | to_entries[0].value.value_percent | rtrimstr("%") | tonumber)})
    | (map(select(.default)) | first) as $cur
    | {volume: ($cur.vol // 0), muted: ($cur.mute // false), name: ($cur.desc // "no output"),
       sinks: map({name, desc, default})}'
}

case "$1" in
  status) status ;;
  set)
    # the slider also fires when the poll sets its value; skip if nothing changed so
    # opening the popup can't nudge the volume (wpctl rounds 100 → 99 otherwise).
    # no refresh here: the slider is the source of truth while dragging.
    want=${2%.*}
    cur=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d", $2*100+0.5}')
    [ "$want" = "$cur" ] || wpctl set-volume @DEFAULT_AUDIO_SINK@ "${want}%" ;;
  mute) run wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; refresh vol "$(status)" ;;
  up) run wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${step}%+"; refresh vol "$(status)" ;;
  down) run wpctl set-volume @DEFAULT_AUDIO_SINK@ "${step}%-"; refresh vol "$(status)" ;;
  sink) run pactl set-default-sink "$2"; refresh vol "$(status)" ;;
  *) usage "status|set N|mute|up|down|sink NAME" ;;
esac
