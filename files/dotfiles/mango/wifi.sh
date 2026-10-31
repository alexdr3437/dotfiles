#!/usr/bin/env sh
# Wifi backend for the eww popup (NetworkManager).
#   wifi.sh status                → JSON {enabled, ssid, networks:[{ssid,signal,secure,active,known}]}
#   wifi.sh toggle | connect SSID | disconnect | forget SSID | rescan
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

wifi_dev() { nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}'; }
enabled() { [ "$(nmcli radio wifi)" = enabled ]; }

status() {
  en=false; enabled && en=true
  known=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}')
  # one row per SSID: prefer the connected BSSID, else the strongest (done in jq below)
  networks=$(nmcli -t --escape no -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list \
    | awk -F: 'NF>=4 && $2!=""' \
    | while IFS=: read -r active ssid signal security; do
        k=false; printf '%s\n' "$known" | grep -qxF -- "$ssid" && k=true
        a=false; [ "$active" = yes ] && a=true
        jq -cn --arg ssid "$ssid" --argjson signal "${signal:-0}" --arg sec "$security" \
          --argjson active "$a" --argjson known "$k" \
          '{ssid:$ssid, signal:$signal, secure:($sec!=""), active:$active, known:$known}'
      done | jq -cs 'group_by(.ssid) | map(sort_by([(.active | not), -.signal]) | first) | sort_by([(.active | not), -.signal])')
  jq -cn --argjson enabled "$en" --argjson networks "${networks:-[]}" \
    '{enabled:$enabled, networks:$networks, ssid:(([$networks[] | select(.active)] | first | .ssid) // "")}'
}

case "$1" in
  status) status ;;
  toggle)
    if enabled; then run nmcli radio wifi off; else run nmcli radio wifi on; fi
    sleep 1; refresh wifi "$(status)" ;;
  connect)
    # saved network → connect directly; new secured network → ask for the password in a terminal
    if nmcli -t -f NAME con show | grep -qxF -- "$2"; then
      run nmcli con up id "$2" >/dev/null 2>&1 || run nmcli dev wifi connect "$2" >/dev/null 2>&1
    else
      ewwc close wifi >/dev/null 2>&1
      ghostty --title="connect to $2" -e sh -c "nmcli --ask dev wifi connect \"$2\" || { echo; echo 'failed — press enter'; read _; }"
    fi
    refresh wifi "$(status)" ;;
  disconnect) run nmcli dev disconnect "$(wifi_dev)" >/dev/null 2>&1; refresh wifi "$(status)" ;;
  forget) run nmcli con delete id "$2" >/dev/null 2>&1; refresh wifi "$(status)" ;;
  rescan) run nmcli dev wifi rescan >/dev/null 2>&1; sleep 2; refresh wifi "$(status)" ;;
  *) usage "status|toggle|connect SSID|disconnect|forget SSID|rescan" ;;
esac
