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
| env.sh | sourced by lib.sh; scripts keep their own `${var:-default}` | `internal_monitor` (monitors.sh), `lock_monitor` (lock.sh), idle timer overrides (idle.sh) |
| waybar.jsonc | `"include"` in waybar.jsonc; nested objects merge, keys set in the main file win | `network.interface` filter |

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
| waybar (top bar) | autostart.sh | waybar.jsonc, waybar.css | ~/.cache/mango/waybar.log |
| eww daemon (popups, taskbar, backdrop) | autostart.sh | eww/eww.yuck, eww/eww.scss | ~/.cache/mango/eww.log |
| swaync | autostart.sh | swaync.json, swaync.css | ~/.cache/mango/swaync.log |
| swaybg | wallpaper.sh | random file in ~/.dotfiles/files/wallpapers | |
| swayidle | idle.sh start | timers at the top of idle.sh, AC vs battery; `idle.sh watch` restarts it when the source changes | |
| monitors.sh watch | autostart.sh | laptop panel off while another monitor exists (`internal_monitor` in hosts/<host>/env.sh); fold/unfold lid binds | |
| gtklock (lock screen) | lock.sh (idle.sh, power popup, Alt+l) | gtklock.css + ~/.cache/mango/lock.png | |
| nightlight.sh daemon → wlsunset | nightlight.sh auto | sun times from weather.sh | |
| polkit-kde agent, nm-applet, blueman-applet | autostart.sh | | |
| rofi | Super+r bind in config.conf | rofi.rasi | |

## Data flow

```
bar click (waybar.jsonc on-click)
  └─ popup.sh <window> [app]      toggle one eww window, close the others, open a backdrop
       └─ ewwc.sh open <window>    eww client wrapper (heals the two-daemon state)

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
| `ewwc ARGS...` | ewwc.sh: the eww client |
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
| battery.sh | bat | custom/battery | upower, plus BLE batteries taken from `bt.sh status` |
| bt.sh | bt | | the only script that parses bluetoothctl (BLE battery needs bluez Experimental) |
| cal.sh | cal | | hand-built month grid; state file in $runtime_dir |
| history.sh | history | custom/history | reads run.sh's log |
| idle.sh | idle | | swayidle wrapper; timers by power source (/sys Mains supply; none → AC); `on-battery` for other scripts |
| monitors.sh | | | internal panel vs externals (`status`, `apply`, `watch`) and lid (`fold`, `unfold`); no-op without `internal_monitor`. Disabled monitors stay in `all-monitors` with width 0 |
| media.sh | media | custom/media (bar-stream) | MPRIS via busctl, no playerctl |
| nightlight.sh | (via settings) | | wlsunset; sun times from `weather.sh cached`, never the network |
| settings.sh | settings | custom/settings | theme / dnd / nightlight / restart |
| sys.sh | sys (deflisten) | custom/sys (bar-stream) | /proc only, no forks per tick |
| taskbar.sh | taskbar | | one eww window per monitor; `.desktop` icon lookups cached in icons.tsv (hits only) |
| vol.sh | vol | pulseaudio (built-in) | pactl + wpctl |
| vpn.sh | vpn | custom/proton (`bar proton`), custom/tailscale (`bar ts`) | NetworkManager + tailscale |
| weather.sh | weather | custom/weather | Open-Meteo, cached 15 min, location pinned while a VPN is up |
| wifi.sh | wifi | network (built-in) | nmcli |

Other scripts: `popup.sh` (window toggling), `theme.sh`, `lock.sh`,
`wallpaper.sh`, `autostart.sh`, `check.sh` (lint, see below).

### Lock screen

`lock.sh` runs gtklock with `gtklock.css` over `~/.cache/mango/lock.png`,
which `wallpaper.sh` regenerates (blurred, dimmed, 1080p) every time it picks
a wallpaper. Only the clock shows until a key press or mouse move; the form
goes on the monitor named by `lock_monitor` in `hosts/<host>/env.sh`
(desktop: HDMI-A-1; empty lets gtklock pick). Falls back to plain swaylock. Both lockers need their PAM service
from `modules/mango.nix`; a locker without one cannot verify the password
and must be killed from a TTY.

## Invariants (do not break these)

1. **Every eww click handler goes through `async.sh`.** eww blocks until
   the handler exits, and a handler that calls `eww update`/`eww close`
   deadlocks with the daemon until eww's timeout kills it. `:timeout` on
   every eventbox is set generously for the same reason (default is 200 ms).
2. **Every real action goes through `run`** (run.sh). That is what makes the
   History popup work and what records exit codes for debugging.
3. **Talk to eww only via `ewwc`** (ewwc.sh), never bare `eww`. eww's client
   auto-starts a second daemon when an IPC call fails; ewwc.sh detects and
   heals that. autostart.sh kills by process name `.eww-wrapped` for the same
   reason (eww's own `kill` misses orphaned daemons).
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
    (`lock_min=${lock_min:-10}`).
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
| $cache_dir/icons.tsv | taskbar.sh | appid → icon name (only successful lookups) |
| $cache_dir/wallpaper, lock.png | wallpaper.sh | current wallpaper path; blurred copy for the lock screen |
| $cache_dir/art/ | media.sh | downloaded album art |
| $cache_dir/*.log | autostart.sh | waybar, eww, swaync output |
| $runtime_dir/mango-* | popup.sh, cal.sh | click timestamps, calendar state |

## Checking and debugging

```sh
~/.config/mango/check.sh                     # shellcheck + eww :initial drift; run after every edit
~/.config/mango/autostart.sh                 # restart everything
~/.config/mango/theme.sh <name>              # also what regenerates $state_dir after a wipe
eww -c ~/.config/mango/eww logs              # eww parse errors land here
~/.config/mango/ewwc.sh active-windows
~/.config/mango/<name>.sh status | jq .      # check a backend by hand
export MANGO_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/mango-*.sock)   # mmsg from a non-mango shell
```

## Known gaps / todo

- `hosts/laptop/` assumes the panel is `eDP-1` (unverified) and the laptop
  still needs brightness/volume key binds and a battery low warning. See
  `docs/mango-laptop-handoff.md`.
- eww taskbar windows are opened once per monitor at autostart; monitor
  hotplug is not handled (`mmsg watch all-monitors` could drive it).
- waybar's network module is filtered to `wl*` on the desktop
  (`hosts/desktop/waybar.jsonc`); the laptop has no filter, so the VPN
  tunnel shows as the connection while Proton is up.
- Super+m quits the session with no confirmation.
