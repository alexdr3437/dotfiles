{
  config,
  pkgs,
  host,
  ...
}:
let
  mango = "${config.home.homeDirectory}/.dotfiles/files/dotfiles/mango";
in
{
  # popups + taskbar daemon (eww.yuck); the rest of the stack is in modules/mango.nix
  home.packages = [ pkgs.eww ];

  # live symlink into the checkout: edits apply without a rebuild, and rollbacks do not cover it
  xdg.configFile."mango".source = config.lib.file.mkOutOfStoreSymlink mango;

  # per-host monitor rules, script variables and waybar overrides; `host` comes from flake.nix
  xdg.configFile."mango-host".source = config.lib.file.mkOutOfStoreSymlink "${mango}/hosts/${host}";

  # GTK theme, icons, cursor and font; mango's own cursor is cursor_theme in config.conf
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
  };
  home.pointerCursor = {
    gtk.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # apps started with the session, as user units. Bitwarden in the background lets the
  # browser extensions unlock through it.
  systemd.user.services =
    let
      sessionApp = description: exec: {
        Unit = {
          Description = description;
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = exec;
          Restart = "on-failure";
          Slice = "app.slice";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    in
    {
      bitwarden = sessionApp "Bitwarden" "${pkgs.bitwarden-desktop}/bin/bitwarden --autostart";
      proton-vpn = sessionApp "Proton VPN" "${pkgs.proton-vpn}/bin/protonvpn-app";
    };

  # "Screenshot" launcher entry for screenshot.sh (satty's own entry is NoDisplay)
  xdg.desktopEntries.screenshot = {
    name = "Screenshot";
    genericName = "Region screenshot with annotation";
    comment = "Drag a region, annotate in satty, Enter copies it to the clipboard";
    exec = "${mango}/screenshot.sh";
    icon = "satty";
    terminal = false;
    categories = [
      "Utility"
      "Graphics"
    ];
    settings.Keywords = "screenshot;capture;snapshot;grim;slurp;satty;";
  };
}
