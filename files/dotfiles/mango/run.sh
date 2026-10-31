#!/usr/bin/env sh
# run.sh <command...> — run it and record it for the History popup:
#   actions.log line:  <epoch> TAB <command> TAB <exit code> TAB <first line of output> TAB <output file>
#   actions/<id>.log:  the full command, exit code and complete output (opened by clicking the row)
# Exit code and output are passed through. Every widget action goes through here
# (scripts call it through the run() wrapper in lib.sh).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
log="$cache_dir/actions.log"
outdir="$cache_dir/actions"
mkdir -p "$outdir"

out=$("$@" 2>&1); rc=$?
first=$(printf '%s' "$out" | head -1 | tr '\t' ' ' | cut -c1-160)
id=$(date +%s%N)
file="$outdir/$id.log"
{
  echo "\$ $*"
  echo "exit code: $rc    $(date '+%a %d %b %-I:%M:%S %p')"
  echo "----------------------------------------"
  printf '%s\n' "$out"
} > "$file"
printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$*" "$rc" "$first" "$file" >> "$log"

# keep things bounded: 500 log lines, and drop output files no longer referenced
if [ "$(wc -l < "$log")" -gt 1000 ]; then
  tail -n 500 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
  for f in "$outdir"/*.log; do grep -qF "$f" "$log" || rm -f "$f"; done
fi

[ -n "$out" ] && printf '%s\n' "$out"
exit $rc
