#!/usr/bin/env sh
# Monitors: the eww taskbar per monitor, the laptop's internal panel, and the lid.
#   monitors.sh names    → enabled monitor names, one per line
#   monitors.sh taskbars → one `taskbar-<mon>` eww window per enabled monitor: open the
#                          missing ones, close the stale ones (autostart.sh, hotplug)
#   monitors.sh status   → JSON {internal, internal_on, externals:[...], want_internal}
#   monitors.sh apply    → disable the internal panel while any other monitor exists,
#                          re-enable it when it is the only one left (idempotent)
#   monitors.sh watch    → apply + taskbars whenever the set of enabled monitors changes
#                          (started by autostart.sh after the eww daemon)
#   monitors.sh fold     → lid closed: on battery suspend, on AC lock + sleep the panel
#   monitors.sh unfold   → lid opened: wake the panel if it is the one in use
# $internal_monitor comes from hosts/<host>/env.sh (laptop: eDP-1); empty (desktop) makes
# apply/fold/unfold panel-free no-ops. To dry-run:  internal_monitor=HDMI-A-2 monitors.sh status
# Enabled vs disabled: mango keeps disabled monitors in `all-monitors` with a zero
# box, so width > 0 means enabled (a DPMS-slept monitor keeps its box).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

names() { mmsg get all-monitors 2>/dev/null | jq -r '.monitors[] | select(.width > 0) | .name'; }

taskbars() {
  want=$(names)
  have=$(ewwc active-windows 2>/dev/null | sed -n 's/^taskbar-\([^:]*\): taskbar$/\1/p')
  for m in $want; do
    printf '%s\n' "$have" | grep -qx -- "$m" \
      || ewwc open taskbar --screen "$m" --id "taskbar-$m" --arg "mon=$m" >/dev/null 2>&1
  done
  for m in $have; do
    printf '%s\n' "$want" | grep -qx -- "$m" || ewwc close "taskbar-$m" >/dev/null 2>&1
  done
}

status() {
  mmsg get all-monitors 2>/dev/null | jq -c --arg i "$internal_monitor" '
    .monitors as $m
    | ($m | map(select(.name != $i and .width > 0) | .name)) as $ext
    | {internal: $i,
       internal_on: ([$m[] | select(.name == $i and .width > 0)] | length > 0),
       externals: $ext,
       want_internal: ($i != "" and ($ext | length) == 0)}'
}

apply() {
  [ -n "$internal_monitor" ] || return 0
  s=$(status) || return 0
  case "$(printf '%s' "$s" | jq -r '"\(.internal_on) \(.want_internal)"')" in
    "true false") run mmsg dispatch disable_monitor,"$internal_monitor" >/dev/null ;;
    "false true") run mmsg dispatch enable_monitor,"$internal_monitor" >/dev/null ;;
  esac
}

watch() {
  # the stream also fires for focus / tag changes, so act only when the set of enabled
  # monitors differs from last time. apply may disable the panel, which fires another
  # event, and that one brings the taskbars in line with the final layout.
  last=""
  sync() {
    now=$(names | sort | tr '\n' ' ')
    [ "$now" = "$last" ] && return
    last=$now
    apply
    taskbars
  }
  sync
  mmsg watch all-monitors 2>/dev/null | while read -r _; do sync; done
}

on_battery() { "$dir/idle.sh" on-battery; }

fold() {
  if on_battery; then
    run systemctl suspend
  else
    run "$dir/lock.sh"
    [ -n "$internal_monitor" ] && [ "$(status | jq -r .internal_on)" = true ] \
      && run mmsg dispatch sleep_monitor,"$internal_monitor" >/dev/null
  fi
}

unfold() {
  # wakeup_monitor would also re-enable a panel that apply disabled, so only when it is in use
  [ -n "$internal_monitor" ] && [ "$(status | jq -r .want_internal)" = true ] \
    && run mmsg dispatch wakeup_monitor,"$internal_monitor" >/dev/null
  apply
}

case "$1" in
  names) names ;;
  taskbars) taskbars ;;
  status) status ;;
  apply) apply ;;
  watch) watch ;;
  fold) fold ;;
  unfold) unfold ;;
  *) usage "names|taskbars|status|apply|watch|fold|unfold" ;;
esac
