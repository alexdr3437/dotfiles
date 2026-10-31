#!/usr/bin/env sh
# Network for the top bar (custom/network): the first connected ethernet or wifi device,
# ethernet preferred, ignoring tunnels (Proton, Tailscale), bridges and loopback.
# waybar's built-in module follows the default route, which is the VPN tunnel while
# Proton is up, and its "interface" filter is one fixed pattern per host, so it could not
# show wifi at home and a USB-C dock's ethernet elsewhere. Rates are in custom/net (sys.sh).
#   network.sh bar   → waybar JSON {text, tooltip, class: wifi|ethernet|offline}
#   network.sh pick  → "DEVICE:TYPE:CONNECTION" of the device bar would show, chosen from
#                      `nmcli -t --escape no -f DEVICE,TYPE,STATE,CONNECTION dev status`
#                      lines on stdin (feed it made-up lines to test the ethernet case)
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

pick() {
  awk -F: '$3 == "connected" && ($2 == "ethernet" || $2 == "wifi") {
             con = $4; for (i = 5; i <= NF; i++) con = con ":" $i   # connection names may contain ":"
             if ($2 == "ethernet" && e == "") e = $1 ":" $2 ":" con
             if ($2 == "wifi" && w == "") w = $1 ":" $2 ":" con
           }
           END { if (e != "") print e; else if (w != "") print w }'
}

wifi_icon() {   # signal % → one of five bars
  case $(( $1 / 20 )) in 0) echo "󰤯" ;; 1) echo "󰤟" ;; 2) echo "󰤢" ;; 3) echo "󰤥" ;; *) echo "󰤨" ;; esac
}

bar() {
  dev=$(nmcli -t --escape no -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null | pick)
  if [ -z "$dev" ]; then
    printf '{"text":"󰖪  offline","tooltip":"no ethernet or wifi connection","class":"offline"}\n'; return
  fi
  name=${dev%%:*}; rest=${dev#*:}; type=${rest%%:*}; con=${rest#*:}
  ip=""; gw=""
  while IFS=: read -r k v; do
    case $k in IP4.ADDRESS*) [ -n "$ip" ] || ip=$v ;; IP4.GATEWAY) gw=$v ;; esac
  done <<EOF
$(nmcli -t --escape no -f IP4.ADDRESS,IP4.GATEWAY dev show "$name" 2>/dev/null)
EOF
  if [ "$type" = wifi ]; then
    sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1 == "yes" {print $2; exit}')
    text="$(wifi_icon "${sig:-0}")  $con"
    tip="$con  ${sig:-0}%\n$name  ${ip:-no ip}\ngw ${gw:-none}"
  else
    text="󰈀  $name"
    tip="$con\n$name  ${ip:-no ip}\ngw ${gw:-none}"
  fi
  jq -cn --arg t "$text" --arg tip "$(printf '%b' "$tip")" --arg c "$type" '{text: $t, tooltip: $tip, class: $c}'
}

case "$1" in
  bar) bar ;;
  pick) pick ;;
  *) usage "bar|pick" ;;
esac
