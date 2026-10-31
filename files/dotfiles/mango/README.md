# ~/.config/mango

Everything for the mango desktop session: compositor config, the top bar
(waybar), the bottom taskbar + click popups (eww), notifications (swaync),
launcher (rofi) and the shell scripts that feed them. Packages come from
`~/.dotfiles/modules/mango.nix`. The directory itself lives in the dotfiles
repo at `files/dotfiles/mango` and `home/mango.nix` links `~/.config/mango`
to it (a live symlink into the checkout, not a store copy, so edits apply
without a rebuild and `theme.sh` can write its generated files here; those are
gitignored and `autostart.sh` regenerates them on a fresh checkout).

Read this before changing anything. The rules below were each learned the
hard way and are easy to break without noticing.

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
| swayidle | idle.sh start | timers hard-coded in idle.sh | |
| gtklock (lock screen) | lock.sh (idle.sh, power popup) | gtklock.css + ~/.cache/mango/lock.png | |
| nightlight.sh daemon → wlsunset | nightlight.sh auto | sun times from weather.sh | |
| polkit-kde agent, nm-applet, blueman-applet | autostart.sh | | |
| rofi | Super+r bind in config.conf | rofi.rasi, rofi-colors.rasi | |

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
  └─ exec "<name>.sh bar"        (JSON {text, tooltip, class}; "bar-stream" variants loop forever)
```

### Backend script contract

One script per concern, POSIX sh, no bashisms. Each one is a `case "$1"`:

- `status` → one JSON object for eww (shape documented in the script header
  and mirrored in the defpoll `:initial` in eww.yuck; keep them in sync or
  eww fails to parse while the first poll is pending)
- `bar` → waybar JSON `{text, tooltip, class}`; `bar-stream` loops for
  modules without an `interval`
- actions (`toggle`, `connect MAC`, …) → do the thing via `run.sh`, then
  `refresh` (push new status to eww)

| script | eww var | bar module | notes |
| --- | --- | --- | --- |
| battery.sh | bat | custom/battery | upower + bluetoothctl (BLE needs bluez Experimental) |
| bt.sh | bt | | bluetooth module is waybar built-in |
| cal.sh | cal | | hand-built month grid; state file in $XDG_RUNTIME_DIR |
| history.sh | history | custom/history | reads run.sh's log |
| idle.sh | idle | | swayidle wrapper |
| media.sh | media | custom/media | MPRIS via busctl, no playerctl |
| nightlight.sh | (via settings) | | wlsunset, schedule from weather.sh sun times |
| settings.sh | settings | custom/settings | theme / dnd / nightlight / restart |
| sys.sh | sys (deflisten) | custom/sys | /proc only, no forks per tick |
| taskbar.sh | taskbar | | one eww window per monitor |
| vol.sh | vol | pulseaudio (built-in) | pactl + wpctl |
| vpn.sh | vpn | custom/proton, custom/tailscale | NetworkManager + tailscale |
| weather.sh | weather | custom/weather | Open-Meteo, cached 15 min, location pinned while a VPN is up |
| wifi.sh | wifi | network (built-in) | nmcli |

Helpers: `async.sh` (detach), `run.sh` (log + passthrough), `ewwc.sh` (eww
client), `popup.sh` (window toggling), `theme.sh`, `lock.sh`, `wallpaper.sh`.

Lock screen: `lock.sh` runs gtklock with `gtklock.css` (imports theme.css)
over `~/.cache/mango/lock.png`, which `wallpaper.sh` regenerates (blurred,
dimmed, 1080p) every time it picks a wallpaper. Only the clock shows until a
key press or mouse move; the form goes on the monitor named by
`--monitor-priority` in lock.sh (desktop: HDMI-A-1). Alt+l locks. Falls back
to plain swaylock.
Both lockers need their PAM service from `modules/mango.nix`; a locker without
one cannot verify the password and must be killed from a TTY.

## Invariants (do not break these)

1. **Every eww click handler goes through `async.sh`.** eww blocks until
   the handler exits, and a handler that calls `eww update`/`eww close`
   deadlocks with the daemon until eww's timeout kills it. `:timeout` on
   every eventbox is set generously for the same reason (default is 200 ms).
2. **Every real action goes through `run.sh`.** That is what makes the
   History popup work and what records exit codes for debugging.
3. **Talk to eww only via `ewwc.sh`, never bare `eww`.** eww's client
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
7. **Themes only define colours.** `themes/<name>.css` uses GTK
   `@define-color` with catppuccin names. `theme.sh` relinks `theme.css` and
   regenerates `eww/_colors.scss` and `rofi-colors.rasi`; never edit those
   three by hand. Nothing outside `themes/` may contain a literal hex colour
   (known exception: the notification badge in waybar.jsonc).
8. **Scripts find the config dir via `$HOME/.config/mango`**, because eww
   and waybar run them with an arbitrary cwd. `~` is fine inside eww.yuck
   and waybar.jsonc, which shell-expand.
9. **Timing constants** live at the top of the script that uses them
   (`dbl` double-click windows in popup.sh and cal.sh, `tick` in sys.sh,
   timers in idle.sh and nightlight.sh).

## Generated and state files

| path | written by | purpose |
| --- | --- | --- |
| theme.css (symlink) | theme.sh | current theme |
| eww/_colors.scss, rofi-colors.rasi | theme.sh | theme in scss / rasi syntax |
| nightlight.off | nightlight.sh | exists → user turned night light off |
| ~/.cache/mango/{actions.log,actions/} | run.sh | History popup data |
| ~/.cache/mango/{weather,geo}.json | weather.sh | forecast cache, pinned location |
| ~/.cache/mango/icons.tsv | taskbar.sh | appid → icon name (never invalidated) |
| ~/.cache/mango/wallpaper, lock.png | wallpaper.sh | current wallpaper path; blurred copy for the lock screen |
| ~/.cache/mango/art/ | media.sh | downloaded album art |
| $XDG_RUNTIME_DIR/mango-* | popup.sh, cal.sh | click timestamps, calendar state |

## Debugging

```sh
~/.config/mango/autostart.sh                 # restart everything
eww -c ~/.config/mango/eww logs              # eww parse errors land here
eww -c ~/.config/mango/eww active-windows
~/.config/mango/<name>.sh status | jq .      # check a backend by hand
export MANGO_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/mango-*.sock)   # mmsg from a non-mango shell
```

## Known gaps / todo

- No per-host config: monitor rules in config.conf are the desktop's
  (HDMI-A-2 / HDMI-A-1). The laptop needs eDP-1 rules or lid `switchbind`s,
  brightness/volume key binds, a battery low warning, and power-aware idle
  timers. Mango supports `source=` / `source_optional=` for a host file.
- eww taskbar windows are opened once per monitor at autostart; monitor
  hotplug is not handled (`mmsg watch all-monitors` could drive it).
- waybar's network module is filtered to `wl*`; wired dock connections show
  as offline.
- Generated files above live inside the config dir, which blocks managing
  it from the dotfiles repo. Moving them to ~/.cache or ~/.local/state is
  the prerequisite.
