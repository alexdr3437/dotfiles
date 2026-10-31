#!/usr/bin/env sh
# Started once per session by `exec_once` in config.conf.
# Safe to re-run by hand: each component is killed before it's restarted.
# (pkill -f on the command line: NixOS wraps binaries so -x name never matches)
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
log="$cache_dir"

# first login on a machine: theme.css and the files theme.sh derives from it don't exist yet
[ -e "$state_dir/theme.css" ] || "$dir/theme.sh" catppuccin-mocha >/dev/null 2>&1

# idle lock / screen off / suspend on battery (no-op until swayidle + wlopm are installed);
# the watcher swaps the timers when the power source changes (exits at once without a mains supply)
"$dir/idle.sh" start
pkill -f "^upower --monitor"; pkill -f "$dir/idle.sh watch"
"$dir/idle.sh" watch >/dev/null 2>&1 &
"$dir/nightlight.sh" auto   # unless turned off in settings

# laptop panel off while an external monitor is connected (no-op without $internal_monitor)
pkill -f '^mmsg watch all-monitors'; pkill -f "$dir/monitors.sh watch"
"$dir/monitors.sh" watch >/dev/null 2>&1 &

# wallpaper (random from ~/.dotfiles/files/wallpapers)
"$dir/wallpaper.sh" >/dev/null 2>&1 &

# polkit agent: password prompts for nm / blueman / systemctl
pkill -f '^[^ ]*polkit-kde-authentication-agent-1'
/run/current-system/sw/libexec/polkit-kde-authentication-agent-1 >/dev/null 2>&1 &

# notifications
pkill -f '^swaync '
swaync -c "$dir/swaync.json" -s "$dir/swaync.css" >"$log/swaync.log" 2>&1 &

# tray applets (right-click menus for wifi / bluetooth)
pkill -f '^nm-applet'
nm-applet --indicator >/dev/null 2>&1 &
pkill -f '^[^ ]*python[^ ]* [^ ]*blueman-applet'  # it's a python script
blueman-applet >/dev/null 2>&1 &

# popups + taskbar daemon
for p in $(pgrep -x .eww-wrapped); do kill "$p"; done   # eww kill misses orphaned daemons
eww -c "$dir/eww" daemon >"$log/eww.log" 2>&1 &
sleep 1.5
for mon in $(mmsg get all-monitors 2>/dev/null | jq -r '.monitors[].name'); do   # grouped taskbar, one per monitor
  eww -c "$dir/eww" open taskbar --screen "$mon" --id "taskbar-$mon" --arg "mon=$mon" >/dev/null 2>&1
done

# bars (needs swaync running first for the notification module)
pkill -f '^waybar '
waybar -c "$dir/waybar.jsonc" -s "$dir/waybar.css" >"$log/waybar.log" 2>&1 &
