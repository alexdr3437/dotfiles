{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        user = "alex";
        command = "${pkgs.hyprland}/bin/Hyprland";
      };
      default_session = initial_session;
    };
    restart = false;
  };

  environment.systemPackages = with pkgs; [
    hyprpaper
    waybar
    hyprpicker
    hyprlock
    walker
    grim
    slurp
    swappy
    wl-clipboard
    mako
    dunst
    libnotify
  ];
}
