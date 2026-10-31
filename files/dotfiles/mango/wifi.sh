#!/usr/bin/env sh
# Wifi backend for the eww popup (NetworkManager).
#   wifi.sh status                → JSON {enabled, ssid, networks:[{ssid,signal,secure,active,known}]}
#   wifi.sh toggle | connect SSID | disconnect | forget SSID | rescan
cfg="$HOME/.config/mango/eww"

wifi_dev() { nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}'; }

status() {
  enabled=$([ "$(nmcli radio wifi)" = enabled ] && echo true || echo false)
  known=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}')
  # one row per SSID: prefer the connected BSSID, else the strongest (done in jq below)
  networks=$(nmcli -t --escape no -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list \
    | awk -F: 'NF>=4 && $2!=""' \
    | while IFS=: read -r active ssid signal security; do
        k=$(printf '%s\n' "$known" | grep -qxF -- "$ssid" && echo true || echo false)
        a=$([ "$active" = yes ] && echo true || echo false)
        jq -cn --arg ssid "$ssid" --argjson signal "${signal:-0}" --arg sec "$security" \
          --argjson active "$a" --argjson known "$k" \
          '{ssid:$ssid, signal:$signal, secure:($sec!=""), active:$active, known:$known}'
      done | jq -cs 'group_by(.ssid) | map(sort_by([(.active | not), -.signal]) | first) | sort_by([(.active | not), -.signal])')
  jq -cn --argjson enabled "$enabled" --argjson networks "${networks:-[]}" \
    '{enabled:$enabled, networks:$networks, ssid:(([$networks[] | select(.active)] | first | .ssid) // "")}'
}

refresh() { "$HOME/.config/mango/ewwc.sh" update "wifi=$(status)" >/dev/null 2>&1; }

case "$1" in
  status) status ;;
  toggle)
    if [ "$(nmcli radio wifi)" = enabled ]; then "$HOME/.config/mango/run.sh" nmcli radio wifi off; else "$HOME/.config/mango/run.sh" nmcli radio wifi on; fi
    sleep 1; refresh ;;
  connect)
    # saved network → connect directly; new secured network → ask for the password in a terminal
    if nmcli -t -f NAME con show | grep -qxF -- "$2"; then
      "$HOME/.config/mango/run.sh" nmcli con up id "$2" >/dev/null 2>&1 || "$HOME/.config/mango/run.sh" nmcli dev wifi connect "$2" >/dev/null 2>&1
    else
      "$HOME/.config/mango/ewwc.sh" close wifi >/dev/null 2>&1
      ghostty --title="connect to $2" -e sh -c "nmcli --ask dev wifi connect \"$2\" || { echo; echo 'failed — press enter'; read _; }"
    fi
    refresh ;;
  disconnect) "$HOME/.config/mango/run.sh" nmcli dev disconnect "$(wifi_dev)" >/dev/null 2>&1; refresh ;;
  forget) "$HOME/.config/mango/run.sh" nmcli con delete id "$2" >/dev/null 2>&1; refresh ;;
  rescan) "$HOME/.config/mango/run.sh" nmcli dev wifi rescan >/dev/null 2>&1; sleep 2; refresh ;;
  *) echo "usage: wifi.sh status|toggle|connect SSID|disconnect|forget SSID|rescan" >&2; exit 1 ;;
esac
