# ~/.config/mango

Everything for the mango desktop session: compositor config, the top bar
(waybar), the bottom taskbar + click popups (eww), notifications (swaync),
launcher (rofi), lock screen (gtklock) and the shell scripts that feed them.
Packages come from `~/.dotfiles/modules/mango.nix`. The directory lives in the
dotfiles repo at `files/dotfiles/mango`; `home/mango.nix` links
`~/.config/mango` to it as a live symlink into the checkout, so edits apply
without a rebuild. Nothing is ever written into this directory at runtime:
generated files go to `~/.local/state/mango`, caches to `~/.cache/mango`.

Read this before changing anything, and run `check.sh` after. The rules
below were each learned the hard way and are easy to break without noticing.

## Per-host settings: `hosts/<host>/`

Everything that differs between the desktop and the laptop lives in
`hosts/<host>/` (`desktop`, `laptop`), reached through the symlink
`~/.config/mango-host` that `home/mango.nix` creates (`host` is passed in
`home-manager.extraSpecialArgs` in flake.nix). It cannot live inside
`~/.config/mango` because that is the repo checkout itself. Three files, one per
consumer:

| file | consumer | holds |
| --- | --- | --- |
| mango.conf | `source_optional=~/.config/mango-host/mango.conf` at the end of config.conf | monitor rules, lid `switchbind`s |
| env.sh | sourced by lib.sh; scripts keep their own `${var:-default}` | `internal_monitor` (monitors.sh), `lock_monitor` (lock.sh), `screenshot_dir` (screenshot.sh), `ephemeral_w`/`ephemeral_h` (ephemeral.sh), idle timer overrides (idle.sh), `soft_lock_min` for the password-free lock screen (desktop) |
| waybar.jsonc | `"include"` in waybar.jsonc; nested objects merge, keys set in the main file win | nothing at the moment (`{}`) |

Every include is optional so a missing link only means desktop-ish defaults
and mango's automatic monitor layout; `check.sh` fails when the link or one of
the three files is absent, and parses `mango.conf` with `mango -p` (an error
inside a `source`d file is only printed by mango, not fatal, so it checks the
host file on its own). Mango reloads config.conf and every sourced file when
they change (`auto_reload_config=1`, the default); waybar and the scripts pick
the other two up on restart.

## Process tree

`config.conf` has `exec_once=autostart.sh`. autostart.sh is idempotent
(kills each component before starting it) and is also what the settings
popup's "Restart bar & popups" runs.

| process | started by | config | log |
| --- | --- | --- | --- |
| waybar (top bar) | bar.sh (from autostart.sh): a supervisor loop restarts it if it exits; the soft lock stops and starts it | waybar.jsonc, waybar.css | ~/.cache/mango/waybar.log |
| eww daemon (popups, taskbar, backdrop) | autostart.sh | eww/eww.yuck, eww/eww.scss | ~/.cache/mango/eww.log |
| swaync | autostart.sh | swaync.json, swaync.css | ~/.cache/mango/swaync.log |
| swaybg | wallpaper.sh | random file in ~/.dotfiles/files/wallpapers | |
| swayidle | idle.sh start | timers in idle.sh and hosts/<host>/env.sh, AC vs battery (see "Lock screen"); `idle.sh watch` restarts it when the source changes; also sets logind IdleHint (see idle.sh) | |
| monitors.sh watch | autostart.sh (after eww) | taskbar per enabled monitor, re-synced on hotplug; laptop panel off while another monitor exists (`internal_monitor` in hosts/<host>/env.sh); fold/unfold lid binds | |
| gtklock (lock screen) | lock.sh (first `exec_once` at session start since greetd autologs in, idle.sh, lid close on AC via monitors.sh fold, power popup, Alt+m; Ctrl+Alt+Delete runs `lock.sh relock`) | gtklock.css + ~/.cache/mango/lock.png | |
| nightlight.sh daemon → wlsunset | nightlight.sh auto | sun times from weather.sh | |
| soteria (polkit agent), nm-applet, blueman-applet | autostart.sh | | |
| drives.sh watch | autostart.sh | udev block add → notification with "Mount and open" / "Mount" (udisksctl, then Dolphin) | |
| rofi (app launcher, clipboard history, emoji picker) | Super+r → launcher.sh pick, Super+v → clip.sh pick, Super+period → emoji.sh | rofi.rasi | |
| clip.sh watch | autostart.sh | `wl-paste --watch cliphist store` for text and images | |
| hex (voice dictation) | `hex.service` user unit from hex's home-manager module (modules/dictation.nix), with graphical-session.target | hold Ctrl+Super in config.conf → `hex dictation start/stop` (a `dictation` key mode, see the comment there); Ctrl+Space → `hex annotate toggle`, Ctrl+Shift+Space → `hex annotate draw` (no shortcuts portal, so hex cannot bind them itself); settings in the `hex` window; models in ~/.local/share/hex | `journalctl --user -u hex` |
| grim + slurp + satty (screenshots) | Super+t → screenshot.sh | | |

## Data flow

```
bar click (waybar.jsonc on-click)
  └─ popup.sh <window> [app]      toggle one eww window, close the others, open a backdrop per monitor
       └─ ewwc.sh active-windows  / open-many ...    eww client wrapper (--no-daemonize; heals the two-daemon state on failure)

eww window (eww.yuck)
  ├─ reads a defpoll var    ← "<name>.sh status"  (JSON, polled only while a window using it is open)
  └─ click handler          → async.sh <name>.sh <action>
                                 └─ run.sh <real command>      logged for the History popup
                                 └─ ewwc.sh update <var>=...   push fresh state without waiting for the poll
waybar custom module (waybar.jsonc)
  └─ exec "<name>.sh bar"        (JSON {text, tooltip, class}; "bar-stream" loops forever)
```

## Scripts

### lib.sh (sourced by every script)

```sh
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
```

Defines the paths and the only way scripts talk to the primitives:

| name | meaning |
| --- | --- |
| `$dir` | this directory |
| `$cache_dir` | `~/.cache/mango`: logs, weather/geo cache, album art, icon cache, lock.png |
| `$state_dir` | `~/.local/state/mango`: theme.css link, colors.scss, rofi-colors.rasi, nightlight.off |
| `$runtime_dir` | `$XDG_RUNTIME_DIR`: click timestamps |
| `$host_dir` | `~/.config/mango-host` → `hosts/<host>`; its `env.sh` is sourced here if present |
| `$dbl_ms` | double-click window (popup.sh, cal.sh) |
| `run CMD...` | run.sh: execute and record for the History popup |
| `ewwc ARGS...` | the eww client (`eww --no-daemonize`; ewwc.sh heals + retries on failure) |
| `refresh VAR JSON` | push new state to eww now instead of waiting for the poll |
| `now_ms`, `usage`, `device_glyph KIND` | helpers |

Primitives (standalone, called through the wrappers above): `async.sh`
(detach a click handler), `run.sh` (log + passthrough), `ewwc.sh` (eww client).

### Backend contract

One script per concern, POSIX sh, no bashisms, a `case "$1"` at the bottom:

| subcommand | output | used by |
| --- | --- | --- |
| `status` | one JSON object for eww | defpoll in eww.yuck |
| `stream` | `status` repeated forever | deflisten in eww.yuck (sys only) |
| `bar [variant]` | waybar JSON `{text, tooltip, class}` | waybar.jsonc exec |
| `bar-stream` | `bar` repeated forever | modules without an `interval` |
| actions (`toggle`, `connect MAC`, …) | runs the thing via `run`, then `refresh VAR "$(status)"` | eww click handlers |

The defpoll `:initial` in eww.yuck must have the same keys as `status`
(`check.sh` verifies this against the live output).

| script | eww var | bar module | notes |
| --- | --- | --- | --- |
| bar.sh | | | runs waybar under a supervisor that restarts it if it exits; `restart` (autostart.sh), `stop`/`show` (softlock.sh). Never hide the bar with SIGUSR1: the toggle is per bar, and a monitor that sleeps gets a new, visible bar, so the next toggle hides it |
| battery.sh | bat | custom/battery, custom/draw | upower, plus BLE batteries taken from `bt.sh status`; `bar` fires the low-battery notification at 20 and 10 % (`warn`); `bar draw` is the power draw in W: the battery while discharging, else the CPU package from RAPL (`/sys/devices/virtual/powercap`, opened by modules/mango.nix; delta kept in `$cache_dir/draw.rapl`) plus the GPU from nvidia-smi when the driver reports it; the tooltip names the parts |
| bt.sh | bt | | the only script that parses bluetoothctl (BLE battery needs bluez Experimental) |
| cal.sh | cal | | hand-built month grid; state file in $runtime_dir |
| clip.sh | | | clipboard history: `watch` records every copy into cliphist, `pick` is a rofi over it (Super+v), `wipe` forgets it |
| emoji.sh | | | rofimoji in the rofi theme, types + copies; recent picks on Super+1…0 (rofi's Alt+N defaults are mango's tag keys); Super+period |
| drives.sh | | | removable drives: `watch` runs `added NAME` per udev add event → notify-send with action buttons; `mount NAME [open]` via udisksctl, `open` shows it in Dolphin. Nothing auto-mounts |
| ephemeral.sh | | | `run [--stash] CMD…`: float + centre the command's first window (three mmsg streams on one fifo: all-clients for map/float/unmap, focusing-client for the global focus, all-devices for input; events are logged to $cache_dir/ephemeral.log), then close it — or `--stash` minimize it — when another app's window is used (a key press, click or scroll; hover focus does not count), unless it was promoted: tiled (Alt+t) or `keep` (Alt+p); fullscreen is not a promotion, but nothing closes it while fullscreen. Used by drives.sh, popup.sh double-clicks and launcher.sh Shift+Enter |
| launcher.sh | | | app launcher (Super+r): .desktop entries in rofi dmenu mode (icons, usage-sorted via $cache_dir/launcher.tsv, keywords searchable); Enter launches, Shift+Enter ephemeral --stash, Ctrl+t in ghostty. Replaces `rofi -show drun`, whose Shift+Enter is just Enter |
| history.sh | history | custom/history | reads run.sh's log |
| palette.sh | | | command palette: every `bind=` in config.conf plus a few unbound actions, in rofi with label · description · keys; descriptions in `describe()`; Super+Shift+p |
| layout.sh | | | rofi dmenu of `mmsg get layouts` with a description per row, current one preselected; Super+Shift+n |
| screenshot.sh | | | `slurp -d` region → `grim` → `satty` (annotate; Enter copies, Ctrl+S saves to `$screenshot_dir`, default ~/Pictures/Screenshots); Super+t |
| softlock.sh | | | password-free idle screen: `show`/`hide` the eww `softlock` window on every monitor; run by idle.sh (see "Lock screen") |
| idle.sh | idle | | swayidle wrapper; timers by power source (/sys Mains supply; none → AC); `on-battery` for other scripts |
| media.sh | media | custom/media (bar-stream) | MPRIS via busctl, no playerctl |
| monitors.sh | | | `names` (enabled monitors), `taskbars` (one eww taskbar per monitor), internal panel vs externals (`status`, `apply`, `watch`) and lid (`fold`, `unfold`). Disabled monitors stay in `all-monitors` with width 0 |
| network.sh | | custom/network | first connected ethernet or wifi device, tunnels ignored; `pick` reads nmcli lines from stdin for tests |
| nightlight.sh | (via settings) | | wlsunset; sun times from `weather.sh cached`, never the network |
| settings.sh | settings | custom/settings | theme / dnd / nightlight / restart |
| sys.sh | sys (deflisten) | custom/sys (bar-stream), custom/net (`bar-stream net`, 1s) | /proc only, no forks per tick; net rates over the physical interfaces every 1s; `top` padded to exactly 5 so the popup uses fixed rows (a `for` rebuilt its children every 2s and flickered) |
| taskbar.sh | taskbar | | one eww window per monitor: grouped apps, then a dimmed section with that monitor's minimized windows (click restores through `focusid`, which un-minimizes); right-click opens the `taskmenu` window above the pointer (minimize / maximize / quit (all) for a group, restore / quit for a minimized window); `.desktop` icon lookups cached in icons.tsv (hits only) |
| vol.sh | vol | pulseaudio (built-in) | pactl + wpctl |
| vpn.sh | vpn | custom/proton (`bar proton`), custom/tailscale (`bar ts`) | NetworkManager + tailscale |
| weather.sh | weather | custom/weather | Open-Meteo, cached 15 min; location from ipinfo.io (https, ip-api.com fallback), pinned while a VPN is up |
| wifi.sh | wifi | | nmcli (the popup) |

Other scripts: `popup.sh` (window toggling), `theme.sh`, `lock.sh`,
`wallpaper.sh`, `autostart.sh`, `check.sh` (lint, see below).

### Lock screen

`lock.sh` runs gtklock with `gtklock.css` over `~/.cache/mango/lock.png`,
which `wallpaper.sh` regenerates (blurred, dimmed, 1080p) every time it picks
a wallpaper. Only the clock shows until a key press or mouse move; the form
starts on the monitor named by `lock_monitor` in `hosts/<host>/env.sh`
(desktop: HDMI-A-1; empty lets gtklock pick), then follows the keyboard (below). Falls back to plain swaylock.
Both lockers need their PAM service from `modules/mango.nix`; a locker without
one cannot verify the password and must be killed from a TTY.

Monitors may come and go while locked (powered off overnight, unplugged):
gtklock is patched (`modules/gtklock-monitor-hotplug.patch`) so the form moves
to whichever screen mango gives the keyboard and a returning monitor gets a
window again; stock 4.0.0 could end with no screen showing the form and Enter
doing nothing. If the form is ever stuck anyway, **Ctrl+Alt+Delete** (`bindl`, so
it works while locked) runs `lock.sh relock`: it kills the locker and starts a
fresh one. mango keeps the session locked while no locker runs and hands the
lock to the next, so this never unlocks anything.

Idle on the desktop: after `soft_lock_min` (5) the password-free lock screen
(`softlock.sh`; waybar is stopped while it shows), which the first key, pointer move or click ends; the password
lock only after `ac_lock_min` (120). Both are set in `hosts/desktop/env.sh`; the
laptop sets neither and locks with the password after 5 minutes on AC, 2 on battery. Alt+m, the
power popup, boot and sleep always lock with the password.

Video holds both idle timers off: Firefox takes a Wayland idle inhibitor, which mango
honours while the window is visible (`idle_inhibit_ignore_visible=0`). It only reaches
Wayland because modules/mango.nix turns the Inhibit portal off; the portal reads that
once at start, under `XDG_CURRENT_DESKTOP=mango` from the user manager (`systemctl --user
show-environment`), so restart `xdg-desktop-portal` after a rebuild changes it. A second
mango (a headless test) must run without `DBUS_SESSION_BUS_ADDRESS`, or its exit blanks
WAYLAND_DISPLAY, DISPLAY and XDG_CURRENT_DESKTOP in the live user manager.

## Invariants (do not break these)

1. **Every eww click handler goes through `async.sh`.** eww blocks until
   the handler exits, and a handler that calls `eww update`/`eww close`
   deadlocks with the daemon until eww's timeout kills it. `:timeout` on
   every eventbox is set generously for the same reason (default is 200 ms).
2. **Every real action goes through `run`** (run.sh). That is what makes the
   History popup work and what records exit codes for debugging.
3. **Talk to eww only via `ewwc`** (lib.sh), never bare `eww`. eww's client
   auto-starts a second daemon when an IPC call fails; `ewwc` passes
   `--no-daemonize` so that cannot happen, and when a call fails it runs
   ewwc.sh, which checks the daemons (none → start one, several → kill all,
   start one) and retries once. popup.sh's run time is the click-to-popup
   delay, so it makes two eww calls per click (active-windows, open-many) and
   the daemon check is only on the failure path. autostart.sh kills by process
   name `.eww-wrapped` for the same reason (eww's own `kill` misses orphaned
   daemons).
4. **`pkill -f` on the full command line, never `pkill -x name`.** NixOS
   wraps binaries, so the process name is `.foo-wrapped`, not `foo`.
5. **Popups never take keyboard focus** (`:focusable false`) and are always
   closed by `popup.sh close`, which also drops the backdrop windows. The
   backdrop is an invisible fullscreen eww window per monitor; clicking or
   scrolling it closes everything. `Super+Escape` is the escape hatch.
6. **One CSS class per widget in eww.yuck.** Multi-class strings did not
   match reliably. Custom widget params cannot be named `visible`.
7. **Themes only define colours, and nothing else contains one.**
   `themes/<name>.css` uses GTK `@define-color` with catppuccin names.
   `theme.sh` links `$state_dir/theme.css` to it and derives `colors.scss`
   (eww) and `rofi-colors.rasi` (rofi) next to it; never edit those by hand.
   waybar.css, swaync.css, gtklock.css, eww.scss and rofi.rasi import them
   by the literal path `/home/alex/.local/state/mango/…` (CSS cannot expand
   `~`). No literal hex colour outside `themes/`; waybar colours state via
   the module's `class` and a rule in waybar.css.
8. **Scripts find everything through lib.sh** (`$dir`, `$cache_dir`,
   `$state_dir`), never a hard-coded path; eww and waybar run them with an
   arbitrary cwd. `~` is fine inside eww.yuck and waybar.jsonc, which
   shell-expand.
9. **This directory is read-only at runtime.** Anything a script writes goes
   to `$state_dir` (survives logins, user choices) or `$cache_dir`
   (regenerable). That keeps the git tree clean and will let the directory
   become a store copy later.
10. **Timing constants** live at the top of the script that uses them
    (`tick` in sys.sh, timers in idle.sh and nightlight.sh) or in lib.sh
    when shared (`dbl_ms`). Ones that differ per machine are set in
    `hosts/<host>/env.sh` and the script keeps the fallback
    (`ac_lock_min=${ac_lock_min:-5}`).
11. **Nothing machine-specific outside `hosts/`.** No monitor names, interface
    patterns or per-machine timers in config.conf, the scripts or
    waybar.jsonc; add a key to the host files instead (see "Per-host settings").

## State and cache files

| path | written by | purpose |
| --- | --- | --- |
| $state_dir/theme.css (symlink) | theme.sh | current theme; autostart.sh creates it on first login |
| $state_dir/colors.scss, rofi-colors.rasi | theme.sh | theme in scss / rasi syntax |
| $state_dir/nightlight.off | nightlight.sh | exists → user turned night light off |
| $cache_dir/{actions.log,actions/} | run.sh | History popup data |
| $cache_dir/{weather,geo}.json | weather.sh | forecast cache, pinned location |
| $cache_dir/battery.warned | battery.sh | last low-battery level warned about; removed when charging |
| $cache_dir/icons.tsv | taskbar.sh | appid → icon name (only successful lookups) |
| $cache_dir/wallpaper, lock.png | wallpaper.sh | current wallpaper path; blurred copy for the lock screen |
| $cache_dir/art/ | media.sh | downloaded album art |
| $cache_dir/*.log | autostart.sh | waybar, eww, swaync output |
| $runtime_dir/mango-* | popup.sh, cal.sh | click timestamps, calendar state |

## Checking and debugging

```sh
~/.config/mango/check.sh                     # shellcheck, host link + mango -p, eww :initial drift; run after every edit
~/.config/mango/autostart.sh                 # restart everything
~/.config/mango/theme.sh <name>              # also what regenerates $state_dir after a wipe
eww -c ~/.config/mango/eww logs              # eww parse errors land here
~/.config/mango/ewwc.sh active-windows
~/.config/mango/<name>.sh status | jq .      # check a backend by hand
export MANGO_INSTANCE_SIGNATURE=$(echo $XDG_RUNTIME_DIR/mango-*.sock)   # mmsg from a non-mango shell (not ls: an -F alias appends =)
```

## Known gaps / todo

The laptop has been rebuilt and checked over ssh (link, logind, binaries,
`idle.sh status`), but nothing has run in a Mango session there yet. To check,
in a Mango session on the laptop:

- Plug the HDMI monitor in and out: `monitors.sh status`, the panel goes
  black and comes back, the taskbar follows.
- Lid close on battery → suspend; on wall power → panel asleep, lock (the lock
  only completes once the lid is open again); open → panel back if in use, and
  still on after unlocking (the old order slept it after unfold had woken it).
- Unplug: `idle.sh status` says battery and `pgrep -af swayidle` shows
  120/300 s; plug back → 300/7200 s (lock / screens off).
- Brightness and media keys; `wev` names a key that does nothing.
- Battery past 20 % once for the notification, or
  `battery.sh warn 19 discharging test`.
- If ethernet is ever plugged in on either machine, the bar should switch to
  the wired glyph within 5 s.

Optional: give the laptop a store copy of this directory instead of the live
symlink (one condition on `host` in home/mango.nix) so it cannot drift from
what was built.
