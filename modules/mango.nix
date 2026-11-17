{ pkgs, inputs, ... }:
let
  # waybar master, for the mango/* modules; cava off because upstream's nix build of it is broken
  waybar = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar.overrideAttrs (old: {
    mesonFlags = (pkgs.lib.remove "-Dcava=enabled" old.mesonFlags) ++ [ "-Dcava=disabled" ];
  });
  # patch: highlight jumps back to the first result when the query changes
  rofi = pkgs.rofi.override {
    rofi-unwrapped = pkgs.rofi-unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./rofi-reset-selection.patch ];
    });
  };
  # patch: keep the password form reachable when a monitor disappears while locked
  gtklock = pkgs.gtklock.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./gtklock-monitor-hotplug.patch ];
  });
in
{
  # mango.nixosModules.mango is imported in flake.nix

  # the mango package + session file; greetd (modules/greetd.nix) boots straight into it
  programs.mango.enable = true;

  # lock screen (lock.sh); the module registers its PAM service. swaylock is the fallback.
  programs.gtklock = {
    enable = true;
    package = gtklock;
  };
  security.pam.services.swaylock = { };

  # gsettings backend for GTK apps
  programs.dconf.enable = true;

  # battery.sh reads upower; power off when critical (the laptop cannot hibernate)
  services.upower = {
    enable = true;
    criticalPowerAction = "PowerOff";
  };

  # tools used by ~/.config/mango (files/dotfiles/mango, see its README)
  environment.systemPackages = with pkgs; [
    rofi
    swaybg # wallpaper
    waybar # status bar
    swaynotificationcenter # notifications + panel (swaync)
    libnotify # notify-send
    swaylock # fallback lock screen (lock.sh)
    imagemagick # blurs the wallpaper for the lock screen
    wlsunset # night light toggle in the settings popup
    swayidle # idle lock / screen off (idle.sh)
    wlopm # screen power control for idle.sh
    brightnessctl # brightness keys (laptop)
    # screenshots (screenshot.sh): slurp picks the region, grim grabs, satty annotates
    grim
    slurp
    satty
    soteria # polkit agent
    imv # image viewer
    cliphist # clipboard history (clip.sh, Super+v)
    rofimoji # emoji picker (Super+period), types with wtype
    wtype
  ];

  # no Inhibit portal backend, so Firefox uses Wayland idle-inhibit (`[ ]` would fall back to gtk)
  xdg.portal.config.mango."org.freedesktop.impl.portal.Inhibit" = pkgs.lib.mkForce [ "none" ];

  # users group may read the RAPL energy counters, for the bar's power-draw module
  systemd.tmpfiles.rules = [
    "z /sys/devices/virtual/powercap/intel-rapl/intel-rapl:*/energy_uj 0440 root users - -"
  ];

  # images open in imv
  xdg.mime.defaultApplications = builtins.listToAttrs (
    map
      (t: {
        name = "image/${t}";
        value = "imv.desktop";
      })
      [
        "png"
        "jpeg"
        "gif"
        "webp"
        "bmp"
        "svg+xml"
        "tiff"
        "avif"
        "heif"
        "x-icns"
      ]
  );
}
