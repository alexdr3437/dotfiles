#!/usr/bin/env sh
# System stats backend.
#   sys.sh stream      → eww JSON every $tick (top processes every 2s); deflisten runs it while the popup is open
#   sys.sh bar-stream  → waybar JSON every $tick; waybar keeps it running (no "interval" in the module)
#   sys.sh status|bar  → one-shot versions of the above
# Each tick only reads /proc files with shell builtins — no subprocesses — so 0.5s is cheap.
# JSON: {cpu, load, cores, temp, mem:{used,total,pct}, swap:{used,total,pct}, top:[{name,cpu,mem}]}
# (the one script that does not source lib.sh: it needs no paths and nothing from it)

tick=0.5
cores=$(nproc)
for h in /sys/class/hwmon/hwmon*; do
  case $(cat "$h/name" 2>/dev/null) in
    coretemp|k10temp|zenpower|cpu_thermal) tempfile="$h/temp1_input"; break ;;
  esac
done

prev_total=0; prev_idle=0
gib() { v=$(( $1 * 10 / 1048576 )); gib_out="$((v / 10)).$((v % 10))"; }   # kB → "x.y" GiB, no forks

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
  top_json=$(ps -eo pid,pcpu,pmem,comm --sort=-pcpu --no-headers | head -8 \
    | awk -v me="$$" '$1 != me && $4 != "ps" {c=$2; m=$3; $1=""; $2=""; $3=""; sub(/^ +/, ""); printf "%s\t%s\t%s\n", $0, c, m}' \
    | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], cpu: (.[1] | tonumber), mem: (.[2] | tonumber)}) | .[:5]')
}

emit_status() {
  printf '{"cpu":%d,"load":"%s","cores":%d,"temp":%d,"mem":{"used":%s,"total":%s,"pct":%d},"swap":{"used":%s,"total":%s,"pct":%d},"top":%s}\n' \
    "$cpu" "$load" "$cores" "$temp" "$mem_used" "$mem_total" "$mem_pct" "$swap_used" "$swap_total" "$swap_pct" "${top_json:-[]}"
}
emit_bar() {
  class=ok; { [ "$cpu" -gt 85 ] || [ "$mem_pct" -gt 90 ]; } && class=high
  printf '{"text":"󰻠 %2d%%  󰍛 %sG","tooltip":"cpu %d%% · load %s · %d°C\\nmemory %s / %s GiB","class":"%s"}\n' \
    "$cpu" "$mem_used" "$cpu" "$load" "$temp" "$mem_used" "$mem_total" "$class"
}

case "$1" in
  status) sample; sleep 0.3; sample; top; emit_status ;;
  bar)    sample; sleep 0.3; sample; emit_bar ;;
  stream)
    sample; sleep 0.2; tickn=0           # (not "n": sample() reads /proc/stat's nice counter into n)
    while :; do
      sample
      [ $((tickn % 4)) -eq 0 ] && top    # every 2s
      emit_status; tickn=$((tickn + 1)); sleep $tick
    done ;;
  bar-stream)
    sample; sleep 0.2
    while :; do sample; emit_bar; sleep $tick; done ;;
  *) echo "usage: sys.sh status|stream|bar|bar-stream" >&2; exit 1 ;;
esac
