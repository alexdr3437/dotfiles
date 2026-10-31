# Mango desktop: laptop readiness handoff

Written 2026-10-31 at the end of a review + cleanup session. Everything below
is what a fresh agent needs to finish making the mango desktop work on the
work laptop. Read `files/dotfiles/mango/README.md` first; it holds the
architecture and the invariants (sourcing `lib.sh`, `async.sh` / `run` /
`ewwc`, `pkill -f`, themes own all colours, config dir is read-only at
runtime). Run `~/.config/mango/check.sh` after every edit.

## Current state

- Config lives in `files/dotfiles/mango`, linked to `~/.config/mango` by
  `home/mango.nix` (live out-of-store symlink, edits apply without rebuild).
- Packages and PAM come from `modules/mango.nix` (waybar from its flake
  input, gtklock via `programs.gtklock`, swaylock as fallback, swayidle,
  wlopm, wlsunset, imagemagick, swaync, rofi, swaybg).
- Only `hosts/desktop` imports `modules/mango.nix`. **`hosts/laptop` does
  not import it yet.** The laptop uses KDE today, has TLP, and a
  `bluetooth-watchdog` service for its Intel AX211.
- Last commits on `main`: `fb8d2c2` (lib.sh + state dir + lint),
  `3c6188c` (bluetooth dedupe). Working tree clean. Nothing pushed.
- Desktop monitors: HDMI-A-2 (1440p, left, scale 1) and HDMI-A-1 (4K,
  right, scale 1.5). Laptop: one external monitor, internal panel to be
  disabled, name not yet known (probably `eDP-1`; confirm with
  `mmsg get all-monitors` or `wlr-randr` once mango runs there).

## Target behaviour on the laptop

Battery-powered, one external monitor, laptop screen disabled while docked.
The user also wants it usable undocked, so "eDP always off" is wrong.

## Issues, in the order to tackle them

### 1. Per-host config split (do this first; it decides the shape)

`config.conf` hard-codes the desktop's monitor rules:

```ini
monitor_rule=name:HDMI-A-2,x:0,y:0,scale:1
monitor_rule=name:HDMI-A-1,x:2560,y:0,scale:1.5
```

Mango supports `source=<file>` and `source_optional=<file>` in config.conf
(see docs/configuration/toml.md in the mango source; the source is at
`nix eval --raw --impure --expr '(builtins.getFlake (toString ~/.dotfiles)).inputs.mango.outPath'`).
Plan:

- Move monitor rules (and anything else host-specific: idle timers, lid
  binds) into `files/dotfiles/mango/hosts/<host>.conf`.
- `config.conf` ends with `source=~/.config/mango/host.conf` (check whether
  mango expands `~`; the rest of config.conf uses absolute `/home/alex/...`).
- `home/mango.nix` writes/links `host.conf` per host. `home/` is shared by
  both hosts via `home-manager.users.alex = import ./home`, so pass the
  host name in (e.g. `home-manager.extraSpecialArgs` already exists in
  flake.nix; add `host = "desktop"` / `"laptop"` there) and pick the file.
  Keep the config dir read-only at runtime: either link `host.conf` from
  the store or point `source=` at the per-host file directly.
- Also split: `idle.sh` timers, the waybar network `interface` filter
  (see item 7), and gtklock `--monitor-priority HDMI-A-1` in `lock.sh`.

### 2. Lid handling / disabling the internal panel

Monitor rule parameters that matter (docs/configuration/monitors.md):
`name` (regex), `x`, `y`, `scale`, `disable:1`, `primary:1`. Commands:
`disable_monitor`, `enable_monitor`, `toggle_monitor`, `sleep_monitor`,
`wakeup_monitor`, all taking a monitor spec like `eDP-1`.

Lid switch bindings exist:

```ini
switchbind=fold,disable_monitor,eDP-1
switchbind=unfold,enable_monitor,eDP-1
```

They require logind to ignore the lid:

```nix
services.logind.settings.Login = {
  HandleLidSwitch = "ignore";
  HandleLidSwitchDocked = "ignore";
  HandleLidSwitchExternalPower = "ignore";
};
```

Recommended: lid-driven (fold disables eDP, unfold re-enables). A static
`disable:1` rule is simpler but leaves zero outputs when the external
monitor is unplugged. Trade-off to confirm with the user: with
`HandleLidSwitch=ignore`, closing the lid on battery no longer suspends;
pair it with an idle suspend (item 5) or a `fold` bind that also runs
`systemctl suspend` when no external monitor is present (`mmsg get
all-monitors | jq '.monitors | length'`).

Verify: `wlopm --on '*'` in `idle.sh`'s resume hook must not re-light a
disabled eDP-1 (wlopm only sees heads mango still exposes; check).

### 3. eww taskbar does not survive monitor hotplug

`autostart.sh` opens one `taskbar-<mon>` eww window per monitor once at
login. Dock/undock leaves the new monitor without a taskbar and eww holding
a window for a vanished output. Waybar (no `output` key → one bar per
output) and swaybg handle hotplug themselves.

Fix: a small watcher started from autostart.sh:

```sh
mmsg watch all-monitors | while read -r _; do
  # diff current monitors against open taskbar-* windows (ewwc active-windows),
  # open missing ones, close stale ones
done
```

`mmsg watch all-monitors` streams a JSON object on every change (confirmed
in `mmsg --help`). `popup.sh` already opens backdrops per monitor
dynamically, so only the taskbar needs this. Kill the watcher in
autostart.sh before restarting (`pkill -f 'mmsg watch all-monitors'`).
Note eww pitfall from the README: a previous directory move left the eww
daemon alive but unreachable; the fix was killing `.eww-wrapped` and
restarting the daemon + taskbars.

### 4. No low-battery warning

`battery.sh bar` only colours the module (`class: low` under 20%). Add:
`notify-send -u critical` when the laptop battery crosses 20% and 10% while
discharging (track the last warned level in `$cache_dir/battery.warned` so
it fires once per crossing; it is polled every 30 s by waybar), and
`services.upower.criticalPowerAction = "HybridSleep"` or similar in nix
(check that `services.upower.enable` is on; KDE's module probably enables it,
but the laptop may drop KDE).

### 5. Idle timers ignore power source

`idle.sh` runs swayidle with fixed 10 min lock / 15 min screens off and no
suspend. On battery add a suspend timeout (e.g. 30 min) and shorter screen
off. Detect AC with `upower -i $(upower -e | grep line_power)` or
`/sys/class/power_supply/AC*/online`; simplest is per-host timers via the
host split, plus an `on-battery` branch. Also add `lock "$dir/lock.sh"` to
the swayidle args so `loginctl lock-session` works. swayidle has no
`-w`-safe reload; restart it when the power source changes if you want
dynamic timers (a udev or upower `--monitor` loop), otherwise keep it
static per host.

### 6. No hardware keys

`config.conf` has no binds for XF86MonBrightnessUp/Down, XF86AudioRaise/
LowerVolume/Mute, XF86AudioPlay/Next/Prev. `brightnessctl` is not
installed (add to `modules/mango.nix`). Volume should go through
`vol.sh`-style wpctl calls so the bar and popup agree; media through
`media.sh playpause|next|prev`. Mango docs/bindings/keys.md has a "Media
Controls" section with the key names.

### 7. Waybar network module hides wired dock connections

`waybar.jsonc` sets `"interface": "wl*"` to avoid showing the Proton tunnel
as the default route. On a USB-C dock with ethernet the bar says offline
while online. Options: per-host interface pattern (host split), or drop the
filter and instead exclude VPN interfaces (waybar has no exclude; a
`custom/network` via `nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status`
picking the first non-vpn connected device is the robust route).

### 8. Super+m quits the session with no confirmation

`bind=SUPER,m,quit` in config.conf. Remove it (the power popup has Log out)
or route it through a confirmation.

### 9. Minor

- Weather geolocation uses plain-HTTP ip-api.com and pins the location;
  on a corporate network the pinned city will be the office egress.
  Low stakes; `weather.sh refresh` re-geolocates when no VPN is active.
- `hosts/laptop` still imports `modules/kde.nix`; decide whether mango
  replaces plasma there or sits beside it in sddm (desktop does the latter).
- The laptop's `bluetooth-watchdog` power-cycles the adapter; `bt.sh` and
  `battery.sh` tolerate bluetoothctl being briefly empty.

## Constraints and conventions

- No live network experiments on this machine without asking (user rule):
  VPN, routing, and anything that drops the connection.
- Do not run `lock.sh` / gtklock from an autonomous session; it locks the
  user's screen.
- Commit with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
  Do not push.
- `nixos-rebuild` needs sudo; ask the user to run
  `sudo nixos-rebuild switch --flake .#desktop` (or `#laptop`). Nix flakes
  only see tracked files: `git add` new files before evaluating.
- Evaluate without building:
  `nix eval .#nixosConfigurations.laptop.config.<option>`.
- Everything desktop-side can be tested live through the symlink; the
  laptop itself is not reachable from this session, so laptop-specific
  behaviour (lid, eDP name, dock) must be verified by the user.
