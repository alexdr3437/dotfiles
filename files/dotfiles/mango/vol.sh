#!/usr/bin/env sh
# Volume backend for the eww popup (pipewire via pactl/wpctl).
#   vol.sh status             → JSON {volume, muted, name, sinks:[{name,desc,default}]}
#   vol.sh set N | mute | sink NAME
cfg="$HOME/.config/mango/eww"

status() {
  default=$(pactl get-default-sink)
  pactl -f json list sinks | jq -c --arg d "$default" '
    map({name, desc: .description, mute, default: (.name == $d),
         vol: (.volume | to_entries[0].value.value_percent | rtrimstr("%") | tonumber)})
    | (map(select(.default)) | first) as $cur
    | {volume: ($cur.vol // 0), muted: ($cur.mute // false), name: ($cur.desc // "no output"),
       sinks: map({name, desc, default})}'
}

refresh() { "$HOME/.config/mango/ewwc.sh" update "vol=$(status)" >/dev/null 2>&1; }

case "$1" in
  status) status ;;
  set)
    # the slider also fires when the poll sets its value; skip if nothing changed so
    # opening the popup can't nudge the volume (wpctl rounds 100 → 99 otherwise).
    # no refresh here: the slider is the source of truth while dragging.
    want=${2%.*}
    cur=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d", $2*100+0.5}')
    [ "$want" = "$cur" ] || wpctl set-volume @DEFAULT_AUDIO_SINK@ "${want}%" ;;
  mute) "$HOME/.config/mango/run.sh" wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; refresh ;;
  sink) "$HOME/.config/mango/run.sh" pactl set-default-sink "$2"; refresh ;;
  *) echo "usage: vol.sh status|set N|mute|sink NAME" >&2; exit 1 ;;
esac
