#!/usr/bin/env sh
# Ephemeral windows: launch a command floating and centred, then let the window go unless
# it is promoted. Plasma had nothing like it; it is for the things you open to glance at
# (a mounted drive in Dolphin, pavucontrol from the bar, an app from the launcher).
#   ephemeral.sh run [--stash] CMD...  → spawn CMD, float its first window at
#                                         $ephemeral_w × $ephemeral_h of the monitor (0.6 × 0.7
#                                         unless hosts/<host>/env.sh says otherwise), then watch:
#                                         - Alt+t (tiled): promoted, the wrapper walks away and
#                                           the window stays. Fullscreen (Alt+f) is not a promotion, but
#                                           nothing closes it while it is fullscreen
#                                         - `ephemeral.sh keep` (Alt+p): promoted as it is
#                                         - "clicking off": a click, scroll or key press that
#                                           goes to another app's window closes it, or with
#                                           --stash sends it to the scratchpad (Alt+z / the
#                                           taskbar bring it back). sloppy_focus moves the
#                                           focus on hover, so hovering another window is
#                                           not enough; the window has to be used.
#                                         Windows of the same process (dialogs) never count
#                                         as "another app"; neither do layers (rofi, popups).
#   ephemeral.sh keep                   → promote the focused window (no-op if not ephemeral)
# Callers go through async.sh: `async.sh ephemeral.sh run CMD...` — the wrapper lives as long
# as the window is ephemeral. Everything comes from mango's socket: three `mmsg watch`
# streams (all-clients: map / float / unmap; focusing-client: the global focus; all-devices:
# one line per input event, with the device type) and dispatches targeting the window by id.
# The window opens floating from the start through a runtime tag rule (open_as_floating on
# the current tag, with the zoom open animation) that is withdrawn once it has appeared, so
# nothing slides in tiled and jumps. Verdicts are logged to $cache_dir/ephemeral.log.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
w_ratio=${ephemeral_w:-0.6}; h_ratio=${ephemeral_h:-0.7}
appear_ms=15000   # give up on a window that never shows (the command may just have failed)
own_ms=2000       # after this, any new window counts: single-instance apps hand it to an old process
tick_s=0.2        # the ticker: phase 1 timeouts, phase 2 "did the pointer move since the last tick"
pidfile() { echo "$runtime_dir/mango-ephemeral-$1.pid"; }
log() { echo "$(date +%T) [$id] $*" >> "$cache_dir/ephemeral.log"; }
cursor() { mmsg get cursorpos | jq -c '[(.x | floor), (.y | floor)]'; }

# the rule that makes the next window on this tag open floating; `1` arms it, `0` withdraws
# it (the last matching rule wins). The open animation goes with it: a floating window
# zooming in at its place reads as a popup, the tiled slide-in does not.
open_floating() {
  mmsg dispatch "setoption,tag_rule,open_as_floating:$1,id:$tag,monitor_name:$mon" >/dev/null
  mmsg dispatch "setoption,animation_type_open,$([ "$1" = 1 ] && echo zoom || echo "$anim_open")" >/dev/null
}

# float ID: size the floating window to the ratios and centre it
float() {
  size=$(mmsg get monitor "$mon" | jq -r --arg w "$w_ratio" --arg h "$h_ratio" \
           '"\(.width * ($w | tonumber) | floor),\(.height * ($h | tonumber) | floor)"')
  mmsg dispatch "resizewin,$size" "client,$1" >/dev/null
  mmsg dispatch centerwin "client,$1" >/dev/null
}

run() {
  mode=close; [ "$1" = --stash ] && { mode=stash; shift; }
  [ -n "$1" ] || usage "run [--stash] CMD..."
  set -- "$@"
  known=$(mmsg get all-clients | jq -c '[.clients[].id]')
  read -r mon tag <<EOF
$(mmsg get all-monitors | jq -r '.monitors[] | select(.active) | "\(.name) \(.active_tags[0])"' | head -1)
EOF
  anim_open=$(sed -n 's/^animation_type_open=\([a-z]*\).*/\1/p' "$dir/config.conf" | head -1); anim_open=${anim_open:-slide}

  # the streams, into one fifo so the loops run in this shell (variables, break) and the
  # watchers can be stopped. Lines: {"clients"… / {"id"… / {"name"… (device) / empty (tick)
  fifo=$(mktemp -u "$runtime_dir/mango-ephemeral-fifo-XXXXXX"); mkfifo "$fifo"
  mmsg watch all-clients > "$fifo" & w1=$!
  mmsg watch focusing-client > "$fifo" & w2=$!
  mmsg watch all-devices > "$fifo" & w3=$!
  ( while sleep "$tick_s"; do echo; done ) > "$fifo" & ticker=$!
  exec 3< "$fifo"; rm -f "$fifo"
  id=-
  trap 'kill $w1 $w2 $w3 $ticker 2>/dev/null; rm -f "$(pidfile "$id")"' EXIT

  open_floating 1
  setsid "$@" >/dev/null 2>&1 </dev/null & pid=$!

  # 1. the window: the first new client owned by the spawned process (or a child of it),
  #    or after $own_ms any new client
  id=""; t0=$(now_ms)
  while read -r line <&3; do
    elapsed=$(( $(now_ms) - t0 ))
    [ "$elapsed" -gt "$appear_ms" ] && break
    case "$line" in '{"clients"'*) ;; *) continue ;; esac
    for cand in $(printf '%s' "$line" | jq -r --argjson known "$known" \
                    '.clients[] | select([.id] | inside($known) | not) | "\(.id):\(.pid):\(.is_floating)"'); do
      cpid=${cand#*:}; cpid=${cpid%%:*}
      ppid=$(ps -o ppid= -p "$cpid" 2>/dev/null | tr -d ' ')
      if [ "$cpid" = "$pid" ] || [ "$ppid" = "$pid" ] || [ "$elapsed" -gt "$own_ms" ]; then
        id=${cand%%:*}; floating=${cand##*:}; break
      fi
    done
    [ -n "$id" ] && break
  done
  open_floating 0
  [ -n "$id" ] || { id=-; log "no window for: $*"; exit 0; }   # nothing appeared: not ours to manage
  log "run ($mode): $* → window $id on $mon tag $tag, floating=$floating"
  [ "$floating" = true ] || mmsg dispatch togglefloating "client,$id" >/dev/null
  float "$id"
  echo "$$ $w1 $w2 $w3 $ticker" > "$(pidfile "$id")"   # for keep: the wrapper and what it must take down

  # 2. the lifecycle.
  #    client-list events → gone | floating | promoted | stashed. Events queued before the
  #      window floated still show it tiled, so "promoted" only counts once one has shown it
  #      floating ($armed).
  #    focus events → ours (elsewhere=0) or another app's window (elsewhere=1); only once
  #      the window has had the focus ($seen): one that opens unfocused is not thrown away
  #      before it was ever looked at. Focus alone does nothing: sloppy_focus hands it out on
  #      hover.
  #    input events while elsewhere → a key press: lost. Pointer events: counted; at the next
  #      tick, events without the cursor having moved were a click or a scroll: lost.
  seen=0; armed=0; cpid=""; elsewhere=0; ptr=0; pos=""; fs=0
  while read -r line <&3; do
    case "$line" in
      '{"clients"'*)
        v=$(printf '%s' "$line" | jq -r --argjson id "$id" --argjson armed "$armed" '
          ([.clients[] | select(.id == $id)] | first) as $c
          | if $c == null then "gone"
            elif $armed == 0 then (if $c.is_floating then "floating \($c.pid)" else "wait" end)
            elif $c.is_fullscreen or $c.is_fakefullscreen then "fullscreen"
            elif ($c.is_floating | not) then "promoted"
            elif $c.is_minimized then "stashed"
            else "windowed" end') ;;
      '{"id"'*)
        v=$(printf '%s' "$line" | jq -r --argjson id "$id" --argjson seen "$seen" --arg cpid "$cpid" '
          if .id == null then "wait"
          elif .id == $id then "focused"
          elif $seen == 0 or (.pid | tostring) == $cpid then "wait"
          else "elsewhere \(.appid)" end') ;;
      '{"name"'*)
        [ "$elsewhere" = 1 ] || continue
        case "$line" in *'"type":"keyboard"'*) v="lost (key press)" ;; *'"type":null'*) continue ;; *) ptr=$((ptr + 1)); continue ;; esac ;;
      '')
        [ "$elsewhere" = 1 ] && [ "$ptr" -gt 0 ] || continue
        now=$(cursor); ptr=0
        if [ "$now" = "$pos" ]; then v="lost (click)"; else pos=$now; continue; fi ;;
      *) continue ;;
    esac
    case "$v" in wait|windowed) ;; *) log "$v (seen=$seen armed=$armed elsewhere=$elsewhere fs=$fs)" ;; esac
    case "$v" in
      floating*) armed=1; cpid=${v#floating } ;;
      fullscreen) fs=1 ;;
      windowed) fs=0 ;;
      focused) seen=1; elsewhere=0 ;;
      elsewhere*) [ "$armed" = 1 ] || continue; elsewhere=1; ptr=0; pos=$(cursor) ;;
      lost*) [ "$fs" = 0 ] || continue   # fullscreen: nothing is "off" it; it goes back to ephemeral when it leaves fullscreen
             case "$mode" in
               stash) mmsg dispatch minimized "client,$id" >/dev/null ;;
               *) mmsg dispatch killclient "client,$id" >/dev/null ;;
             esac; break ;;
      gone|promoted|stashed) break ;;
    esac
  done
}

# keep: the focused window stays as it is; its wrapper (and the wrapper's mmsg watches) just stop
keep() {
  id=$(mmsg get focusing-client | jq -r '.id // empty'); [ -n "$id" ] || exit 0
  f=$(pidfile "$id"); [ -s "$f" ] || exit 0
  read -r wpid helpers < "$f"; rm -f "$f"
  grep -q ephemeral.sh "/proc/$wpid/cmdline" 2>/dev/null || exit 0   # stale file, id reused
  # shellcheck disable=SC2086  # the helper pids are a list
  kill $helpers "$wpid" 2>/dev/null   # watchers, ticker, wrapper; the app is the wrapper's child too and is left alone
  log "kept"
}

case "$1" in
  run) shift; run "$@" ;;
  keep) keep ;;
  *) usage "run [--stash] CMD... | keep" ;;
esac
