{ pkgs, inputs, ... }:
let
  # waybar master for the mango/* modules (not in a release as of 0.15.0).
  # cava is disabled: upstream's nix/default.nix copies cava to the wrong
  # subprojects dir, so meson tries to download it and the build fails.
  waybar = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar.overrideAttrs (old: {
    mesonFlags = (pkgs.lib.remove "-Dcava=enabled" old.mesonFlags) ++ [ "-Dcava=disabled" ];
  });
  # rofi keeps the highlighted row (as an index) across refilters, so after
  # arrowing down and typing on, Enter runs whatever landed on that row. The
  # patch moves the highlight back to the first result whenever the entry text
  # changes; upstream has no option for it (view.c, rofi 2.0.0).
  rofi = pkgs.rofi.override {
    rofi-unwrapped = pkgs.rofi-unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./rofi-reset-selection.patch ];
    });
  };
  # gtklock 4.0.0 loses the password form when a monitor goes away while locked
  # (powered off overnight, unplugged): the window that inherits it is never marked
  # focused, so no screen shows the form again and Enter does nothing; the only way
  # out was a reboot. The patch takes upstream's fix for the removal (unreleased as
  # of 4.0.0), gives the form to a returning monitor when no window holds it, and
  # moves the form to whichever window mango gives the keyboard, so typing always
  # lands in a visible field. See gtklock-monitor-hotplug.patch.
  gtklock = pkgs.gtklock.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./gtklock-monitor-hotplug.patch ];
  });
in
{
  # mango.nixosModules.mango is imported in flake.nix

  # the mango package + session file; greetd (modules/greetd.nix) boots straight into it
  programs.mango.enable = true;

  # lock screen: gtklock (clock + password box over a blurred copy of the
  # wallpaper, see ~/.config/mango/lock.sh). The module also registers its PAM
  # service; a locker without one can never verify the password and a locked
  # session can only be killed from a TTY. swaylock stays as the fallback.
  programs.gtklock = {
    enable = true;
    package = gtklock;
  };
  security.pam.services.swaylock = { };

  # gsettings backend for the GTK apps and home-manager's gtk module. Plasma used
  # to pull it in; without it GTK falls back to a memory backend and warns.
  programs.dconf.enable = true;

  # battery.sh reads upower; its low-battery notification fires at 20 and 10 %.
  # upower itself hybrid-sleeps at percentageAction (2 %) as the last resort.
  # Declared here so it does not depend on the plasma module being present.
  services.upower = {
    enable = true;
    criticalPowerAction = "HybridSleep";
  };

  # ~/.config/mango/ → files/dotfiles/mango (linked by home/mango.nix, see its
  # README.md): config.conf, the bar, the popups and the scripts behind them.
  # Super+r opens rofi, Alt+m locks.
  environment.systemPackages = with pkgs; [
    rofi
    swaybg # wallpaper, started by ~/.config/mango/autostart.sh
    waybar # status bar, started by ~/.config/mango/autostart.sh
    swaynotificationcenter # notifications + panel (swaync)
    libnotify # notify-send
    swaylock # fallback lock screen (lock.sh)
    imagemagick # wallpaper.sh blurs the wallpaper for the lock screen
    wlsunset # night light toggle in the settings popup
    swayidle # idle lock / screen off (idle.sh)
    wlopm # screen power control for idle.sh
    brightnessctl # XF86MonBrightness* binds in config.conf (laptop panel)
    # screenshots (screenshot.sh, Super+t): slurp picks the region, grim grabs
    # it, satty annotates and copies. spectacle's region picker needs KWin.
    grim
    slurp
    satty
    soteria # polkit agent (GTK), started by autostart.sh; was Plasma's polkit-kde-agent
    imv # image viewer (default for image/* below); gwenview went with Plasma
    cliphist # clipboard history: clip.sh watch (autostart.sh) records, Super+v picks
    rofimoji # emoji picker on Super+period, types with wtype (falls back to the clipboard)
    wtype
  ];

  # No Inhibit portal, so video stops the idle lock. mango's module means to turn it off with
  # `= [ ]`, but that writes an empty value, which falls back to default=gtk; the gtk backend
  # needs org.freedesktop.ScreenSaver (absent here) and fails, yet Firefox only sees the
  # portal accept the call and never tries Wayland idle-inhibit, which mango honours.
  # With "none" the portal has no Inhibit interface and Firefox falls through to Wayland.
  # The portal reads this once, at start, and only under the desktop name: XDG_CURRENT_DESKTOP=mango
  # must be in the user manager (mango imports it; a stray mango exit blanks it, see the mango
  # README). A rebuild does not restart user services: `systemctl --user restart xdg-desktop-portal`.
  xdg.portal.config.mango."org.freedesktop.impl.portal.Inhibit" = pkgs.lib.mkForce [ "none" ];

  # xdg-open on an image: imv. The user's ~/.config/mimeapps.list still names gwenview first;
  # a missing entry is skipped and this system default is next.
  xdg.mime.defaultApplications = builtins.listToAttrs (
    map (t: { name = "image/${t}"; value = "imv.desktop"; }) [
      "png" "jpeg" "gif" "webp" "bmp" "svg+xml" "tiff" "avif" "heif" "x-icns"
    ]
  );
}
