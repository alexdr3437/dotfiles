#!/usr/bin/env sh
# System stats backend.
#   sys.sh stream      → eww JSON every $tick (top processes every 2s); deflisten runs it while the popup is open
#   sys.sh bar-stream  → waybar JSON every $tick; waybar keeps it running (no "interval" in the module)
#   sys.sh bar-stream net → waybar JSON every 1s with the down/up rates (custom/net)
#   sys.sh status|bar  → one-shot versions of the above
# Each tick only reads /proc files with shell builtins — no subprocesses — so 0.5s is cheap.
# JSON: {cpu, load, cores, temp, mem:{used,total,pct}, swap:{used,total,pct},
#        net:{iface, down, up, down_bps, up_bps}, top:[{name, cpu, mem:"340 MiB"} x5]}
# top always has exactly 5 entries (padded with name "") and net is refreshed every 1s,
# so the popup renders fixed rows whose text changes instead of rebuilding widgets.
# net sums the physical interfaces (those with a /sys/class/net/*/device), which leaves
# out lo, docker, tailscale and VPN tunnels and so does not count tunnelled bytes twice.
# (the one script that does not source lib.sh: it needs no paths and nothing from it)

tick=0.5
cores=$(nproc)
for h in /sys/class/hwmon/hwmon*; do
  case $(cat "$h/name" 2>/dev/null) in
    coretemp|k10temp|zenpower|cpu_thermal) tempfile="$h/temp1_input"; break ;;
  esac
done

prev_total=0; prev_idle=0
net_ifaces=""; for d in /sys/class/net/*; do [ -e "$d/device" ] && net_ifaces="$net_ifaces ${d##*/}"; done
prev_rx=0; prev_tx=0; down=0; up=0
gib() { v=$(( $1 * 10 / 1048576 )); gib_out="$((v / 10)).$((v % 10))"; }   # kB → "x.y" GiB, no forks
rate() {   # bytes/s → "x.y MiB/s" | "x KiB/s" | "x B/s", no forks
  if [ "$1" -ge 1048576 ]; then v=$(( $1 * 10 / 1048576 )); rate_out="$((v / 10)).$((v % 10)) MiB/s"
  elif [ "$1" -ge 1024 ]; then rate_out="$(( $1 / 1024 )) KiB/s"
  else rate_out="$1 B/s"; fi
}

# net DT_MS: bytes/s over the physical interfaces since the previous call, DT_MS ago
net() {
  rx=0; tx=0
  while read -r name rb _ _ _ _ _ _ _ tb _; do
    name=${name%:}
    case " $net_ifaces " in *" $name "*) rx=$((rx + rb)); tx=$((tx + tb)) ;; esac
  done < /proc/net/dev
  if [ "$prev_rx" -gt 0 ] || [ "$prev_tx" -gt 0 ]; then
    down=$(( (rx - prev_rx) * 1000 / $1 )); up=$(( (tx - prev_tx) * 1000 / $1 ))
    [ "$down" -lt 0 ] && down=0; [ "$up" -lt 0 ] && up=0
  fi
  prev_rx=$rx; prev_tx=$tx
}

sample() {
  read -r _ u n s i w q sq st _ < /proc/stat
  total=$((u + n + s + i + w + q + sq + st)); idle=$((i + w))
  dt=$((total - prev_total)); di=$((idle - prev_idle))
  cpu=0; [ "$prev_total" -gt 0 ] && [ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 100 / dt ))
  prev_total=$total; prev_idle=$idle

  read -r l1 l5 l15 _ < /proc/loadavg; load="$l1 $l5 $l15"
  temp=0; [ -n "$tempfile" ] && { read -r t < "$tempfile"; temp=$((t / 1000)); }

  while read -r k v _; do
    case $k in
      MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; SwapTotal:) swt=$v ;; SwapFree:) swf=$v ;;
    esac
  done < /proc/meminfo
  mu=$((mt - ma)); su=$((swt - swf))
  mem_pct=$(( mt ? mu * 100 / mt : 0 )); swap_pct=$(( swt ? su * 100 / swt : 0 ))
  gib $mu; mem_used=$gib_out;  gib $mt; mem_total=$gib_out
  gib $su; swap_used=$gib_out; gib $swt; swap_total=$gib_out
}

top() {
  # fresh processes (ps itself, this script) report inflated cpu, so drop them; names may contain spaces
  # rss is KiB → "340 MiB" / "1.2 GiB"
  top_json=$(ps -eo pid,pcpu,rss,comm --sort=-pcpu --no-headers | head -8 \
    | awk -v me="$$" '$1 != me && $4 != "ps" {c=$2; m=$3; $1=""; $2=""; $3=""; sub(/^ +/, ""); printf "%s\t%s\t%s\n", $0, c, m}' \
    | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
                   | {name: .[0], cpu: (.[1] | tonumber),
                      mem: ((.[2] | tonumber) | if . >= 1048576 then "\((. * 10 / 1048576 | floor) / 10) GiB" else "\(. / 1024 | floor) MiB" end)})
                   | .[:5] | . + [range(5 - length) | {name: "", cpu: 0, mem: ""}]')   # always 5 rows
}

emit_status() {
  rate "$down"; down_h=$rate_out; rate "$up"; up_h=$rate_out
  printf '{"cpu":%d,"load":"%s","cores":%d,"temp":%d,"mem":{"used":%s,"total":%s,"pct":%d},"swap":{"used":%s,"total":%s,"pct":%d},"net":{"iface":"%s","down":"%s","up":"%s","down_bps":%d,"up_bps":%d},"top":%s}\n' \
    "$cpu" "$load" "$cores" "$temp" "$mem_used" "$mem_total" "$mem_pct" "$swap_used" "$swap_total" "$swap_pct" \
    "${net_ifaces# }" "$down_h" "$up_h" "$down" "$up" "${top_json:-[]}"
}
# compact rate for the bar: "792B" "252K" "1.2M"
rate_short() {
  if [ "$1" -ge 1048576 ]; then v=$(( $1 * 10 / 1048576 )); rate_out="$((v / 10)).$((v % 10))M"
  elif [ "$1" -ge 1024 ]; then rate_out="$(( $1 / 1024 ))K"
  else rate_out="$1B"; fi
}
emit_bar_net() {
  rate_short "$down"; d=$rate_out; rate_short "$up"; u=$rate_out
  rate "$down"; dl=$rate_out; rate "$up"; ul=$rate_out
  printf '{"text":"⇣ %s  ⇡ %s","tooltip":"⇣ %s   ⇡ %s\\n%s","class":"ok"}\n' "$d" "$u" "$dl" "$ul" "${net_ifaces# }"
}
emit_bar() {
  class=ok; { [ "$cpu" -gt 85 ] || [ "$mem_pct" -gt 90 ]; } && class=high
  printf '{"text":"󰻠 %2d%%  󰍛 %sG","tooltip":"cpu %d%% · load %s · %d°C\\nmemory %s / %s GiB","class":"%s"}\n' \
    "$cpu" "$mem_used" "$cpu" "$load" "$temp" "$mem_used" "$mem_total" "$class"
}

case "$1" in
  status) sample; net 300; sleep 0.3; sample; net 300; top; emit_status ;;
  bar)    sample; sleep 0.3; sample; emit_bar ;;
  stream)
    sample; net 1000; sleep 0.2; tickn=0   # (not "n": sample() reads /proc/stat's nice counter into n)
    while :; do
      sample
      [ $((tickn % 2)) -eq 0 ] && net 1000   # every 1s (2 ticks)
      [ $((tickn % 4)) -eq 0 ] && top        # every 2s
      emit_status; tickn=$((tickn + 1)); sleep $tick
    done ;;
  bar-stream)
    if [ "$2" = net ]; then
      net 1000; sleep 1
      while :; do net 1000; emit_bar_net; sleep 1; done
    fi
    sample; sleep 0.2
    while :; do sample; emit_bar; sleep $tick; done ;;
  *) echo "usage: sys.sh status|stream|bar|bar-stream [net]" >&2; exit 1 ;;
esac
