#!/usr/bin/env sh
# VPN backend: Proton VPN (NetworkManager vpn/wireguard connections) + Tailscale.
#   vpn.sh status            → eww JSON {proton:[{name,active}], ts:{online,ip,exit_active,exit_name,exit_options,peers_online,peers}}
#   vpn.sh bar [proton|ts]   → waybar JSON for that module (no variant: one combined module)
#   vpn.sh proton NAME       → toggle that NM connection
#   vpn.sh ts-exit           → toggle the Tailscale exit node (uses the first peer offering one)
#   vpn.sh ts                → tailscale up / down
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

status() {
  proton=$(nmcli -t -f NAME,TYPE,ACTIVE con show 2>/dev/null \
    | awk -F: '$2 == "vpn" || $2 == "wireguard" {printf "%s\t%s\n", $1, $3}' \
    | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], active: (.[1] == "yes")})')
  ts=$(tailscale status --json 2>/dev/null | jq -c '
    (.ExitNodeStatus.ID // null) as $e
    | {online: (.Self.Online // false), ip: ((.Self.TailscaleIPs // [""])[0]),
       exit_active: ($e != null), exit_name: ([.Peer[]? | select(.ID == $e) | .HostName] | first // ""),
       exit_options: [.Peer[]? | select(.ExitNodeOption) | .HostName],
       peers_online: ([.Peer[]? | select(.Online)] | length), peers: ((.Peer // {}) | length)}')
  [ -n "$ts" ] || ts='{"online":false,"ip":"","exit_active":false,"exit_name":"","exit_options":[],"peers_online":0,"peers":0}'
  jq -cn --argjson proton "${proton:-[]}" --argjson ts "$ts" '{proton: $proton, ts: $ts}'
}

bar() {   # variant
  case "$1" in
    proton) status | jq -c '
      ([.proton[] | select(.active) | .name] | first) as $p
      | {text: (if $p != null then "󰒃" else "󰒙" end),
         tooltip: (if $p != null then "proton vpn: \($p)" else "proton vpn off" end),
         class: (if $p != null then "on" else "off" end)}' ;;
    ts) status | jq -c '
      {text: (if .ts.exit_active then "󰩠" else "󰒍" end),
       tooltip: (if .ts.online then "tailscale online · \(.ts.ip)\n\(.ts.peers_online)/\(.ts.peers) peers online" + (if .ts.exit_active then "\nexit node: \(.ts.exit_name)" else "" end) else "tailscale offline" end),
       class: (if .ts.exit_active then "exit" elif .ts.online then "on" else "off" end)}' ;;
    *) status | jq -c '
      ([.proton[] | select(.active) | .name] | first) as $p
      | (if $p != null then "proton: \($p)" elif .ts.exit_active then "tailscale exit: \(.ts.exit_name)" else "" end) as $on
      | {text: (if $on != "" then "󰒃" else "󰒙" end),
         tooltip: ((if $on != "" then $on else "no vpn" end) + "\ntailscale " + (if .ts.online then "online · \(.ts.peers_online)/\(.ts.peers) peers" else "offline" end)),
         class: (if $on != "" then "on" else "off" end)}' ;;
  esac
}

fail() { notify-send -a vpn "VPN" "$1"; }

case "$1" in
  status) status ;;
  bar) bar "$2" ;;
  proton)
    name=${2:?connection name}
    if nmcli -t -f NAME,ACTIVE con show | grep -qxF "$name:yes"; then run nmcli con down id "$name" >/dev/null 2>&1 || fail "couldn't disconnect $name"
    else run nmcli con up id "$name" >/dev/null 2>&1 || fail "couldn't connect $name"; fi
    refresh vpn "$(status)" ;;
  ts-exit)
    if tailscale status --json | jq -e '.ExitNodeStatus != null' >/dev/null; then
      run tailscale set --exit-node= 2>/dev/null || fail "couldn't clear exit node (needs: tailscale operator = $USER)"
    else
      node=$(tailscale status --json | jq -r '[.Peer[]? | select(.ExitNodeOption) | .HostName] | first // ""')
      if [ -n "$node" ]; then run tailscale set --exit-node="$node" 2>/dev/null || fail "couldn't set exit node $node (needs: tailscale operator = $USER)"
      else fail "no exit node offered"; fi
    fi
    sleep 0.5; refresh vpn "$(status)" ;;
  ts)
    if tailscale status --json | jq -e '.Self.Online' >/dev/null; then run tailscale down 2>/dev/null || fail "couldn't stop tailscale (needs: tailscale operator = $USER)"
    else run tailscale up 2>/dev/null || fail "couldn't start tailscale"; fi
    sleep 1; refresh vpn "$(status)" ;;
  *) usage "status|bar [proton|ts]|proton NAME|ts-exit|ts" ;;
esac
