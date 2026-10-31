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
