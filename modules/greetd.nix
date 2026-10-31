{ config, pkgs, ... }:
{
  # Login: greetd, no greeter at boot. It starts mango as alex straight away and the
  # first exec_once in ~/.config/mango/config.conf is lock.sh, so the first thing on
  # screen is the same gtklock screen the session sleeps to. The desktop exists behind
  # the lock from the start; that trade-off is accepted (disks are not encrypted anyway).
  #
  # mango itself exports WAYLAND_DISPLAY / DISPLAY / XDG_CURRENT_DESKTOP=mango to the
  # user systemd instance and dbus (dbus-update-activation-environment in its main.c),
  # which is what the portals conf and the user services key on. XDG_SESSION_TYPE used
  # to come from sddm, so the wrapper sets it; Qt and electron apps read it to pick wayland.
  #
  # If the session ends (logout from the power popup, a crash) greetd falls back to
  # tuigreet, which lists every installed session, so plasma stays reachable while
  # modules/kde.nix is still imported.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.writeShellScript "mango-session" ''
          export XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=mango DESKTOP_SESSION=mango
          exec mango
        ''}";
        user = "alex";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
}
