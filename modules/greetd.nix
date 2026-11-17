{ config, pkgs, ... }:
{
  # No greeter at boot: greetd starts mango as alex and mango's first exec_once is lock.sh.
  # tuigreet if the session ends. The wrapper sets XDG_SESSION_TYPE for Qt and electron.
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
