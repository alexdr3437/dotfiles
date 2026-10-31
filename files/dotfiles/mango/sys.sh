#!/usr/bin/env sh
# System stats backend.
#   sys.sh stream      → eww JSON every $tick (top processes every 2s); deflisten runs it while the popup is open
#   sys.sh bar-stream  → waybar JSON every $tick; waybar keeps it running (no "interval" in the module)
#   sys.sh bar-stream net → waybar JSON every 1s with the down/up rates (custom/net)
#   sys.sh status|bar  → one-shot versions of the above
# Each tick only reads /proc files with shell builtins — no subprocesses — so 0.5s is cheap.
# JSON: {cpu, load, cores, temp, mem:{used,total,pct}, swap:{used,total,pct},
#        net:{iface, down, up, down_bps, up_bps}, top:[{name, cpu:" 37.8", mem:" 950 MiB"} x5]}
# Numbers that sit in labels are padded with U+2007 figure spaces to a fixed width (cpu_pad 3,
# mem/swap used 4, top cpu 5, top mem 4, rates 3) so changing digits never move the text.
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
fs=$(printf "\342\200\207")   # U+2007 figure space: digit-wide, so padded numbers do not shift the text around them
pad() { pad_out=$1; k=$(( $2 - ${#1} )); while [ $k -gt 0 ]; do pad_out="$fs$pad_out"; k=$((k - 1)); done; }

# rate3 BYTES/S → always 3 characters + one unit letter: "792B" " 16K" "128K" "1.2M" " 12M" "1.2G"
rate3() {
  b=$1
  if [ "$b" -lt 1000 ]; then pad "$b" 3; rate3_out="${pad_out}B"
  elif [ "$b" -lt 1024000 ]; then pad $(( (b + 512) / 1024 )) 3; rate3_out="${pad_out}K"   # rounded: 1000 B → "  1K"
  elif [ "$b" -lt 10485760 ]; then v=$((b * 10 / 1048576)); rate3_out="$((v / 10)).$((v % 10))M"
  elif [ "$b" -lt 1048576000 ]; then pad $((b / 1048576)) 3; rate3_out="${pad_out}M"
  else v=$((b * 10 / 1073741824)); rate3_out="$((v / 10)).$((v % 10))G"; fi
}
# rate BYTES/S → the same number with a long unit: "128 KiB/s"
rate() {
  rate3 "$1"; r_n=${rate3_out%?}
  case ${rate3_out#"$r_n"} in B) r_u="B/s" ;; K) r_u="KiB/s" ;; M) r_u="MiB/s" ;; *) r_u="GiB/s" ;; esac
  rate_out="$r_n $r_u"
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
  # pad(n): left-pad with figure spaces (same as pad() above) so the columns stay put
  top_json=$(ps -eo pid,pcpu,rss,comm --sort=-pcpu --no-headers | head -8 \
    | awk -v me="$$" '$1 != me && $4 != "ps" {c=$2; m=$3; $1=""; $2=""; $3=""; sub(/^ +/, ""); printf "%s\t%s\t%s\n", $0, c, m}' \
    | jq -R -s -c --arg fs "$fs" 'def pad(n): tostring | (n - length) as $k | if $k > 0 then ($fs * $k) + . else . end;
                   split("\n") | map(select(length > 0) | split("\t")
                   | {name: .[0], cpu: (.[1] | pad(5)),
                      mem: ((.[2] | tonumber) | if . >= 1048576 then "\(((. * 10 / 1048576 | floor) / 10) | pad(4)) GiB" else "\((. / 1024 | floor) | pad(4)) MiB" end)})
                   | .[:5] | . + [range(5 - length) | {name: "", cpu: "", mem: ""}]')   # always 5 rows
}

emit_status() {
  rate "$down"; down_h=$rate_out; rate "$up"; up_h=$rate_out
  # cpu_pad and the "used" fields are padded strings for the labels; cpu and pct stay numbers for the meters
  pad "$cpu" 3; cpu_p=$pad_out; pad "$mem_used" 4; mem_p=$pad_out; pad "$swap_used" 4; swap_p=$pad_out
  printf '{"cpu":%d,"cpu_pad":"%s","load":"%s","cores":%d,"temp":%d,"mem":{"used":"%s","total":%s,"pct":%d},"swap":{"used":"%s","total":%s,"pct":%d},"net":{"iface":"%s","down":"%s","up":"%s","down_bps":%d,"up_bps":%d},"top":%s}\n' \
    "$cpu" "$cpu_p" "$load" "$cores" "$temp" "$mem_p" "$mem_total" "$mem_pct" "$swap_p" "$swap_total" "$swap_pct" \
    "${net_ifaces# }" "$down_h" "$up_h" "$down" "$up" "${top_json:-[]}"
}
emit_bar_net() {
  rate3 "$down"; d=$rate3_out; rate3 "$up"; u=$rate3_out
  rate "$down"; dl=$rate_out; rate "$up"; ul=$rate_out
  printf '{"text":"⇣ %s  ⇡ %s","tooltip":"⇣ %s   ⇡ %s\\n%s","class":"ok"}\n' "$d" "$u" "$dl" "$ul" "${net_ifaces# }"
}
emit_bar() {
  class=ok; { [ "$cpu" -gt 85 ] || [ "$mem_pct" -gt 90 ]; } && class=high
  pad "$cpu" 3; cpu_p=$pad_out; pad "$mem_used" 4; mem_p=$pad_out
  printf '{"text":"󰻠 %s%%  󰍛 %sG","tooltip":"cpu %d%% · load %s · %d°C\\nmemory %s / %s GiB","class":"%s"}\n' \
    "$cpu_p" "$mem_p" "$cpu" "$load" "$temp" "$mem_used" "$mem_total" "$class"
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
