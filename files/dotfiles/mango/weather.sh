#!/usr/bin/env sh
# Weather backend: Open-Meteo forecast for the location of your public IP (ip-api.com).
# Cached in ~/.cache/mango/weather.json and refreshed at most every 15 min.
# The location is PINNED: it is only re-geolocated while no VPN is active (Proton via
# NetworkManager, or a Tailscale exit node), otherwise the weather would follow the VPN exit.
#   weather.sh status  → eww JSON    weather.sh bar → waybar JSON    weather.sh refresh → force fetch
cache="$HOME/.cache/mango/weather.json"
geofile="$HOME/.cache/mango/geo.json"
maxage=900
empty='{"error":true,"city":"","updated":0,"temp":0,"feels":0,"icon":"󰼯","desc":"no data","humidity":0,"wind":0,"sunrise":"","sunset":"","sunrise24":"","sunset24":"","hourly":[],"daily":[]}'

vpn_active() {
  nmcli -t -f TYPE,ACTIVE con show 2>/dev/null | grep -qE '^(vpn|wireguard):yes' && return 0
  tailscale status --json 2>/dev/null | jq -e '.ExitNodeStatus != null' >/dev/null 2>&1
}

geolocate() {   # → JSON {city,lat,lon}
  if [ -s "$geofile" ] && vpn_active; then cat "$geofile"; return; fi
  geo=$(curl -sf --max-time 5 'http://ip-api.com/json/?fields=status,city,lat,lon') \
    && [ "$(printf '%s' "$geo" | jq -r .status)" = success ] \
    || { [ -s "$geofile" ] && cat "$geofile"; return; }
  if ! vpn_active; then mkdir -p "$(dirname "$geofile")"; printf '%s' "$geo" > "$geofile"; fi
  printf '%s' "$geo"
}

fetch() {
  geo=$(geolocate); [ -n "$geo" ] || return 1
  lat=$(printf '%s' "$geo" | jq -r .lat); lon=$(printf '%s' "$geo" | jq -r .lon)
  city=$(printf '%s' "$geo" | jq -r .city)
  [ "$lat" != null ] || return 1
  raw=$(curl -sf --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day&hourly=temperature_2m,weather_code,precipitation_probability,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=4") || return 1
  mkdir -p "$(dirname "$cache")"
  printf '%s' "$raw" | jq -c --arg city "$city" --arg now "$(date +%s)" '
    # WMO weather codes → nerd-font glyph (day/night) and a short description
    def ic(c; d): if c == 0 then (if d == 1 then "󰖙" else "󰖔" end)
      elif c <= 2 then (if d == 1 then "󰖕" else "󰼱" end) elif c == 3 then "󰖐" elif c <= 48 then "󰖑"
      elif c <= 57 then "󰖗" elif c <= 67 then "󰖖" elif c <= 77 then "󰖘" elif c <= 82 then "󰖖"
      elif c <= 86 then "󰖘" else "󰖓" end;
    def ds(c): if c == 0 then "Clear" elif c == 1 then "Mostly clear" elif c == 2 then "Partly cloudy"
      elif c == 3 then "Overcast" elif c <= 48 then "Fog" elif c <= 57 then "Drizzle" elif c <= 67 then "Rain"
      elif c <= 77 then "Snow" elif c <= 82 then "Showers" elif c <= 86 then "Snow showers" else "Thunderstorm" end;
    # 12-hour clock helpers: "18:13" → "6:13 PM", "21" → "9 PM"
    def h12: (split(":") | (.[0] | tonumber) as $h
      | ((if $h == 0 then 12 elif $h > 12 then $h - 12 else $h end) | tostring) + ":" + .[1] + (if $h < 12 then " AM" else " PM" end));
    def hr12: (. | tonumber) as $h
      | (if $h == 0 then "12 AM" elif $h < 12 then "\($h) AM" elif $h == 12 then "12 PM" else "\($h - 12) PM" end);
    (.current.time[0:13]) as $ct
    | ((.hourly.time | map(.[0:13]) | index($ct)) // 0) as $hi
    | {error: false, city: $city, updated: ($now | tonumber),
       temp: (.current.temperature_2m | round), feels: (.current.apparent_temperature | round),
       icon: ic(.current.weather_code; .current.is_day), desc: ds(.current.weather_code),
       humidity: .current.relative_humidity_2m, wind: (.current.wind_speed_10m | round),
       sunrise: (.daily.sunrise[0][11:16] | h12), sunset: (.daily.sunset[0][11:16] | h12),
       sunrise24: .daily.sunrise[0][11:16], sunset24: .daily.sunset[0][11:16],
       hourly: [range($hi + 1; $hi + 13; 2) as $i | select(.hourly.time[$i] != null)
                | {h: (.hourly.time[$i][11:13] | hr12), temp: (.hourly.temperature_2m[$i] | round),
                   icon: ic(.hourly.weather_code[$i]; .hourly.is_day[$i]), pop: .hourly.precipitation_probability[$i]}],
       daily: [range(0; 4) as $i
                | {day: (if $i == 0 then "Today" else (.daily.time[$i] | strptime("%Y-%m-%d") | strftime("%a")) end),
                   icon: ic(.daily.weather_code[$i]; 1), max: (.daily.temperature_2m_max[$i] | round),
                   min: (.daily.temperature_2m_min[$i] | round), pop: .daily.precipitation_probability_max[$i]}]}' \
    > "$cache.tmp" && mv "$cache.tmp" "$cache"
}

status() {
  age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
  [ "$age" -gt "$maxage" ] && fetch
  [ -s "$cache" ] && cat "$cache" || echo "$empty"
}

case "$1" in
  status) status ;;
  refresh) fetch; "$HOME/.config/mango/ewwc.sh" update "weather=$(status)" >/dev/null 2>&1 ;;
  bar) status | jq -c 'if .error then {text: "󰼯", tooltip: "weather unavailable", class: "error"}
         else {text: "\(.icon) \(.temp)°", tooltip: "\(.city) · \(.desc)\nfeels \(.feels)° · humidity \(.humidity)% · wind \(.wind) km/h", class: "ok"} end' ;;
  *) echo "usage: weather.sh status|bar|refresh" >&2; exit 1 ;;
esac
