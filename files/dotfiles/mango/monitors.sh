#!/usr/bin/env sh
# Internal panel vs external monitors, and the lid (laptop; a no-op where
# $internal_monitor is empty, i.e. the desktop).
#   monitors.sh status   → JSON {internal, internal_on, externals:[...], want_internal}
#   monitors.sh apply    → disable the internal panel while any other monitor exists,
#                          re-enable it when it is the only one left (idempotent)
#   monitors.sh watch    → apply on every monitor change (started by autostart.sh)
#   monitors.sh fold     → lid closed: on battery suspend, on AC lock + sleep the panel
#   monitors.sh unfold   → lid opened: wake the panel if it is the one in use
# $internal_monitor comes from hosts/<host>/env.sh (laptop: eDP-1). To dry-run on the
# desktop:  internal_monitor=HDMI-A-2 monitors.sh status
# Enabled vs disabled: mango keeps disabled monitors in `all-monitors` with a zero
# box, so width > 0 means enabled (a DPMS-slept monitor keeps its box).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

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
  [ -n "$internal_monitor" ] || return 0
  apply
  # the stream also fires for focus / tag changes, so apply has to stay cheap and idempotent;
  # jq -c folds a multi-line object into one line per event
  mmsg watch all-monitors 2>/dev/null | jq -c --unbuffered . | while read -r _; do apply; done
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
  status) status ;;
  apply) apply ;;
  watch) watch ;;
  fold) fold ;;
  unfold) unfold ;;
  *) usage "status|apply|watch|fold|unfold" ;;
esac
