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

  # ~/.config/mango/config.conf (unmanaged) binds Alt+Space to rofi
  environment.systemPackages = with pkgs; [
    rofi
    swaybg # wallpaper, started by ~/.config/mango/autostart.sh
    waybar # status bar, started by ~/.config/mango/autostart.sh
    swaynotificationcenter # notifications + panel (swaync)
    libnotify # notify-send
    wlogout # power menu
    swaylock # lock screen
  ];
}
