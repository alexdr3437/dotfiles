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
  `3c6188c` (bluetooth dedupe), then the per-host split (item 1). Nothing
  pushed.
- Desktop monitors: HDMI-A-2 (1440p, left, scale 1) and HDMI-A-1 (4K,
  right, scale 1.5). Laptop: one external monitor, internal panel to be
  disabled, name not yet known (probably `eDP-1`; confirm with
  `mmsg get all-monitors` or `wlr-randr` once mango runs there).

## Target behaviour on the laptop

Battery-powered, one external monitor over plain HDMI (no dock; the earlier
"dock" wording was an unverified assumption), laptop screen disabled while
that monitor is connected. The user also wants it usable on its own, so "eDP
always off" is wrong.

## Issues, in the order to tackle them

### 1. Per-host config split (DONE 2026-10-31)

Everything machine-specific now lives in `files/dotfiles/mango/hosts/<host>/`
(`desktop`, `laptop`), reached through the symlink `~/.config/mango-host`
that `home/mango.nix` creates from `host` in `home-manager.extraSpecialArgs`
(flake.nix). Three files per host, one per consumer:

- `mango.conf`: `source_optional=~/.config/mango-host/mango.conf` at the end
  of config.conf (mango expands `~` and `./`; it also hot-reloads sourced
  files). Lid `switchbind`s for item 2 go here.
- `env.sh`: sourced by lib.sh; `lock_min`, `off_min` (idle.sh, fallback
  10/15), `lock_monitor` (lock.sh `--monitor-priority`, empty on the laptop).
  Power-aware timers for item 5 start here.
- `waybar.jsonc`: `"include"` in waybar.jsonc, nested objects merge, main
  file wins. Holds the network `interface` filter (`wl*` on the desktop, none
  on the laptop; item 7 still applies).

`check.sh` fails when the link or a file is missing and runs `mango -p` on
config.conf and the host file (errors inside a `source`d file do not change
`mango -p`'s exit code). The README has a "Per-host settings" section and
invariant 11 (nothing machine-specific outside `hosts/`).

State of the desktop: `~/.config/mango-host` was created by hand
(`ln -s`) so the live session kept working; the next `nixos-rebuild switch`
replaces it with the home-manager link (the hand-made one is moved to
`mango-host.hm-bak`, delete it). Verified live: `mmsg dispatch reload_config`
keeps HDMI-A-1 at x=2560 scale 1.5, waybar logs "Including resource file",
swayidle restarts with the env.sh timers, `nix build` of the
`xdg.configFile."mango-host".source` derivation for both hosts points at the
right directory.

`hosts/laptop/` is a skeleton with the lid binds commented out; fill it in
under items 2 and 5.

### 2. Lid handling / internal panel (DONE 2026-10-31, laptop verification pending)

Behaviour the user asked for: panel black whenever an external monitor is
connected, back on automatically when the last one goes; never suspend on wall
power; suspend on battery.

Implementation (`files/dotfiles/mango/monitors.sh`, no-op where
`internal_monitor` is empty, i.e. the desktop):

- `monitors.sh watch` (autostart.sh) applies on every `mmsg watch all-monitors`
  event: externals present → `disable_monitor eDP-1`, none → `enable_monitor`.
  Idempotent: mango keeps disabled monitors in `all-monitors` with a zero box,
  so width > 0 means enabled (a DPMS-slept monitor keeps its box). The stream
  also fires on focus/tag changes, so apply stays cheap.
- Lid: `switchbind=fold/unfold,spawn,monitors.sh fold/unfold` in
  `hosts/laptop/mango.conf`. fold: battery → `systemctl suspend`; AC →
  `lock.sh` + `sleep_monitor` on the panel if it is in use. unfold:
  `wakeup_monitor` only when the panel is the one in use (wakeup would also
  re-enable a panel apply disabled), then apply.
- `hosts/laptop/mango.conf`: `monitor_rule=name:eDP-1,scale:1.25` (name
  assumed, 2560-wide panel). No static `disable:1` so an undocked login has a
  screen.
- Nix: `hosts/laptop` imports `modules/mango.nix` (Mango beside plasma in
  sddm) and sets `services.logind.settings.Login.HandleLidSwitch*=ignore`;
  flake.nix adds `inputs.mango.nixosModules.mango` to the laptop. Evaluated,
  not built.
- `wlopm --on '*'` in idle.sh's resume hook is safe: a disabled output is
  removed from the wlr output layout, which drops its wl_output global, so
  wlopm never sees it (source: handle_output_layout_change in
  src/manage/monitor.c; wlroots creates/destroys the global in
  wlr_output_layout_add/remove).

To verify on the laptop: panel name (`mmsg get all-monitors`; fix in
`hosts/laptop/mango.conf` and `env.sh` if not eDP-1), dock/undock with
`monitors.sh status`, lid close on AC and on battery, that the
`all-monitors` stream really fires on hotplug, and that the panel comes back
after resume (`unfold` runs when the switch state is re-read).

### 3. eww taskbar follows monitor hotplug (DONE 2026-10-31)

`monitors.sh taskbars` diffs the enabled monitors (`monitors.sh names`, width > 0)
against the open `taskbar-*` eww windows, opens the missing and closes the
stale. `monitors.sh watch` runs it (after `apply`) whenever the set of enabled
monitor names changes; the all-monitors stream also fires on focus and tag
changes, so the set is compared first and nothing else happens. autostart.sh no
longer opens taskbars itself: it starts the watcher after the eww daemon, and
restarts it there because the watcher remembers the monitor set and must
re-open everything after an eww restart. `popup.sh` backdrops use the same
`names` so a disabled panel gets no backdrop.

Verified on the desktop: a closed taskbar is re-opened by `taskbars`, a
planted `taskbar-FAKE` is closed, and the running watcher ignores events
that leave the monitor set alone. Not verified: an actual output
add/remove (would move the user's windows; do it on the laptop by
docking, or on the desktop with `mmsg dispatch disable_monitor,HDMI-A-2`
then `enable_monitor`).

### 4. Low-battery warning (DONE 2026-10-31)

`battery.sh bar` (polled every 30 s by waybar) calls `battery.sh warn PERCENT
STATE DETAIL` for the laptop battery: while discharging, a critical
notification once per threshold crossed (20 then 10 %, `warn_levels`), the
last level kept in `~/.cache/mango/battery.warned` and cleared as soon as the
state is not discharging. The synchronous hint makes the 10 % one replace the
20 % one. `modules/mango.nix` declares `services.upower` (enable,
`criticalPowerAction = "HybridSleep"`, which fires at upower's
percentageAction, 2 %) so it does not depend on the plasma module.

Verified on the desktop by driving `warn` by hand through 50 → 19 → 15 → 9 →
charging. On the laptop just let it drain past 20 %, or run
`~/.config/mango/battery.sh warn 19 discharging "test"` for the notification
look.

### 5. Idle timers by power source (DONE 2026-10-31)

`idle.sh` reads the source from /sys (a `Mains` supply that is offline →
battery; no Mains supply → AC, which is the desktop). Both hosts share the
defaults, overridable in `hosts/<host>/env.sh`:

- AC: lock after 5 min, screens off after 60 (`wlopm`), never suspend.
- battery: lock after 2 min, `systemctl suspend` after 5.
- `lock` and `before-sleep` hooks run lock.sh in both (`loginctl
  lock-session` works).

`idle.sh watch` (autostart.sh) follows `upower --monitor` and restarts
swayidle only when the source changes; it exits immediately without a Mains
supply. `idle.sh on-battery` is the shared test for monitors.sh. The settings
popup shows the active set (`idle.source`).

Verify on the laptop: unplug → `idle.sh status` says battery and
`pgrep -af swayidle` shows 120/300 s; plug back → 300/3600 s.

### 6. Hardware keys (DONE 2026-10-31)

config.conf binds XF86AudioRaiseVolume/LowerVolume/Mute → `vol.sh up|down|mute`
(5 % steps, capped at 100, logged through `run`, popup refreshed),
XF86AudioMicMute → `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`,
XF86AudioPlay/Next/Prev → `media.sh playpause|next|prev` (XF86AudioPause is
the same keysym to mango; binding both is a conflict) and
XF86MonBrightnessUp/Down → `brightnessctl set 5%+/-` (`brightnessctl` added to
`modules/mango.nix`; no backlight on the desktop, so a no-op there). Shared, not
per host, since desktop keyboards send the audio keys too. Verify brightness
on the laptop; `wev` shows the names if a key does nothing.

### 7. Network module picks the connected device itself (DONE 2026-10-31)

`custom/network` (`network.sh bar`, every 5 s) replaces waybar's built-in module:
the first connected ethernet or wifi device from `nmcli dev status`, ethernet
preferred, tunnels (Proton, Tailscale), bridges and loopback ignored. The
built-in module followed the default route (the VPN tunnel while Proton is up)
or one fixed interface pattern, so it could not cover wifi at home and a
future USB-C ethernet dock at once. Shows ssid + signal icon or "󰈀 ifname",
tooltip with ip and gateway; `offline` class when nothing qualifies.
`network.sh pick` takes the nmcli lines on stdin, which is how the ethernet,
dock-plus-wifi, tunnels-only and connecting cases were tested; the live wifi
case runs on the desktop. The per-host `waybar.jsonc` files are empty now.
No ethernet exists to test for real yet: plugging the desktop's cable in is
the first chance.

### 8. Super+m quit bind (DONE 2026-10-31)

Removed from config.conf; Log out stays in the power popup.

### 9. Minor (DONE 2026-10-31)

- Weather geolocation now asks ipinfo.io over https first and falls back to
  ip-api.com (http only). Pinning is unchanged and is the intended behaviour:
  the location is only re-read while no VPN is active, so on the office
  network it is the office, which is where the laptop is.
- `hosts/laptop` keeps `modules/kde.nix`; mango sits beside plasma in sddm
  (user decision, item 2).
- `bt.sh status` and `battery.sh bar` were run with a stub `bluetoothctl` that
  prints nothing (the adapter mid power-cycle under the laptop's
  `bluetooth-watchdog`): both return valid JSON (`powered:false`, no devices).

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
  behaviour (lid, eDP name, external monitor hotplug) must be verified by the user.
