{ pkgs, inputs, ... }:
let
  # waybar master for the mango/* modules (not in a release as of 0.15.0).
  # cava is disabled: upstream's nix/default.nix copies cava to the wrong
  # subprojects dir, so meson tries to download it and the build fails.
  waybar = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar.overrideAttrs (old: {
    mesonFlags = (pkgs.lib.remove "-Dcava=enabled" old.mesonFlags) ++ [ "-Dcava=disabled" ];
  });
in
{
  # mango.nixosModules.mango is imported in flake.nix

  # adds a "Mango" session to sddm alongside plasma
  programs.mango.enable = true;

  # lock screen: gtklock (clock + password box over a blurred copy of the
  # wallpaper, see ~/.config/mango/lock.sh). The module also registers its PAM
  # service; a locker without one can never verify the password and a locked
  # session can only be killed from a TTY. swaylock stays as the fallback.
  programs.gtklock.enable = true;
  security.pam.services.swaylock = { };

  # ~/.config/mango/ → files/dotfiles/mango (linked by home/mango.nix, see its
  # README.md): config.conf, the bar, the popups and the scripts behind them.
  # Super+r opens rofi, Alt+l locks.
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
  ];
}
