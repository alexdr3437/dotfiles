#!/usr/bin/env sh
# Sourced by every script in this directory:   . "$HOME/.config/mango/lib.sh"
# Paths, wrappers around the three primitives (run.sh, ewwc.sh, async.sh) and small
# shared helpers. Nothing in here runs anything on its own.
# shellcheck disable=SC2034  # variables are for the sourcing script
dir="$HOME/.config/mango"                               # this directory (symlink into the dotfiles repo)
cache_dir="$HOME/.cache/mango"                          # logs, weather cache, album art, lock.png, icon cache
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mango"  # theme.css + what theme.sh derives from it, nightlight.off
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"                  # click timestamps (popup.sh, cal.sh)
host_dir="$HOME/.config/mango-host"                     # hosts/<host> of this directory (linked by home/mango.nix)
[ -d "$cache_dir" ] && [ -d "$state_dir" ] || mkdir -p "$cache_dir" "$state_dir"   # (no fork once they exist: lib.sh is sourced by every click)

# per-host shell variables (idle timers, lock monitor, ...); each script keeps its own
# default with ${var:-default}, so a missing link only means desktop-ish defaults
# shellcheck source=hosts/desktop/env.sh
[ -r "$host_dir/env.sh" ] && . "$host_dir/env.sh"

dbl_ms=350   # two clicks closer than this count as a double-click (popup.sh, cal.sh)

# eww client. Direct call first (--no-daemonize: never spawn a 2nd daemon); only a failed call pays
# for ewwc.sh, which checks the daemons, heals and retries. Saves a bash start + lib.sh per call.
ewwc() { eww -c "$dir/eww" --no-daemonize "$@" || "$dir/ewwc.sh" "$@"; }
run() { "$dir/run.sh" "$@"; }                         # run a command and record it for the History popup
refresh() { ewwc update "$1=$2" >/dev/null 2>&1; }    # refresh VAR JSON → push fresh state to eww now
now_ms() { date +%s%3N; }
usage() { echo "usage: $(basename "$0") $*" >&2; exit 1; }

# bluetoothctl "Icon:" / upower device type → nerd-font glyph (battery.sh, bt.sh)
device_glyph() {
  case "$1" in
    mouse|input-mouse) echo "󰍽" ;;
    keyboard|input-keyboard) echo "󰌌" ;;
    headset|headphones|audio-headset|audio-headphones) echo "󰋋" ;;
    audio-card) echo "󰓃" ;;
    phone) echo "󰏲" ;;
    gaming-input) echo "󰊗" ;;
    *) echo "󰂯" ;;
  esac
}
