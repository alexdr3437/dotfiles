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
  # --rescan no: by default nmcli rescans when the last scan is stale and blocks for 1-2 s;
  # the popup has its own rescan button. One jq for the whole list instead of one per row.
  # With --escape no an SSID may itself contain ":", so the fields are taken from both ends
  # (ACTIVE first, SIGNAL and SECURITY last) and the middle joined back into the SSID.
  # One row per SSID: prefer the connected BSSID, else the strongest.
  nmcli -t --escape no -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan no \
    | jq -R -s -c --argjson enabled "$en" --arg known "$known" '
        ($known | split("\n") | map(select(length > 0))) as $k
        | [split("\n")[] | select(length > 0) | split(":") | select(length >= 4)
            | {active: (.[0] == "yes"), ssid: (.[1:-2] | join(":")), signal: (.[-2] | tonumber? // 0), secure: (.[-1] != "")}
            | select(.ssid != "") | .known = (.ssid as $s | any($k[]; . == $s))]
        | group_by(.ssid) | map(sort_by([(.active | not), -.signal]) | first) | sort_by([(.active | not), -.signal])
        | {enabled: $enabled, networks: ., ssid: (([.[] | select(.active)] | first | .ssid) // "")}'
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
