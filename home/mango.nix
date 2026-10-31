{ config, pkgs, host, ... }:
let
  mango = "${config.home.homeDirectory}/.dotfiles/files/dotfiles/mango";
in
{
  # popups + taskbar daemon (eww.yuck); the rest of the stack is in modules/mango.nix
  home.packages = [ pkgs.eww ];

  # ~/.config/mango → files/dotfiles/mango as a live symlink into the checkout, not a
  # store copy, so bar / popup / script edits apply without a rebuild (the trade-off:
  # rollbacks do not cover this directory). Nothing writes into it at runtime; generated
  # files go to ~/.local/state/mango and ~/.cache/mango. See its README.md.
  # Packages (mango, waybar, swaync, gtklock, ...) come from modules/mango.nix;
  # jq is in home/default.nix.
  xdg.configFile."mango".source = config.lib.file.mkOutOfStoreSymlink mango;

  # ~/.config/mango-host → files/dotfiles/mango/hosts/<host>: monitor rules
  # (mango.conf, sourced by config.conf), script variables (env.sh, sourced by
  # lib.sh) and waybar overrides (waybar.jsonc, included by waybar.jsonc). It
  # cannot live inside ~/.config/mango because that is the repo checkout itself.
  # `host` comes from home-manager.extraSpecialArgs in flake.nix.
  xdg.configFile."mango-host".source = config.lib.file.mkOutOfStoreSymlink "${mango}/hosts/${host}";

  # GTK look for the mango session (rofi icons, the eww taskbar, swaync, gtklock,
  # any GTK app). Plasma's kde-gtk-config used to write ~/.config/gtk-*/settings.ini
  # with breeze icons, breeze cursors and Noto Sans; these replace them now that
  # Plasma is gone. Noto Sans comes from modules/fonts.nix. The cursor also goes to
  # mango itself: cursor_theme in config.conf, XCURSOR_* for everything else.
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

  # Apps that start with the session. Plasma used to run ~/.config/autostart;
  # mango activates graphical-session.target instead (with WAYLAND_DISPLAY in the
  # user manager), so these are user units: PartOf stops them with the session
  # and starts them again with the next one. `systemctl --user status <name>`.
  # Bitwarden in the background is what lets the browser extensions unlock
  # through the desktop app; --autostart is its own "start minimized" flag.
  systemd.user.services = let
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
  in {
    bitwarden = sessionApp "Bitwarden" "${pkgs.bitwarden-desktop}/bin/bitwarden --autostart";
    proton-vpn = sessionApp "Proton VPN" "${pkgs.proton-vpn}/bin/protonvpn-app";
  };

  # "Screenshot" in the rofi app launcher: the same pipeline as Super+t
  # (screenshot.sh: slurp → grim → satty). satty's own entry is NoDisplay and
  # needs an image, so it never shows up on its own.
  xdg.desktopEntries.screenshot = {
    name = "Screenshot";
    genericName = "Region screenshot with annotation";
    comment = "Drag a region, annotate in satty, Enter copies it to the clipboard";
    exec = "${mango}/screenshot.sh";
    icon = "satty";
    terminal = false;
    categories = [ "Utility" "Graphics" ];
    settings.Keywords = "screenshot;capture;snapshot;grim;slurp;satty;";
  };
}
