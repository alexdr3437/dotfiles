{ config, pkgs, host, ... }:
let
  mango = "${config.home.homeDirectory}/.dotfiles/files/dotfiles/mango";
in
{
  # popups + taskbar daemon (eww.yuck); the rest of the stack is in modules/mango.nix
  home.packages = [ pkgs.eww ];

  # ~/.config/mango → files/dotfiles/mango as a live symlink into the checkout,
  # not a store copy: theme.sh writes generated files next to the config
  # (theme.css, eww/_colors.scss, rofi-colors.rasi; gitignored there), and bar /
  # popup / css edits reload in place without a rebuild. See its README.md.
  # Packages (mango, waybar, swaync, gtklock, ...) come from modules/mango.nix;
  # jq is in home/default.nix.
  xdg.configFile."mango".source = config.lib.file.mkOutOfStoreSymlink mango;

  # ~/.config/mango-host → files/dotfiles/mango/hosts/<host>: monitor rules
  # (mango.conf, sourced by config.conf), script variables (env.sh, sourced by
  # lib.sh) and waybar overrides (waybar.jsonc, included by waybar.jsonc). It
  # cannot live inside ~/.config/mango because that is the repo checkout itself.
  # `host` comes from home-manager.extraSpecialArgs in flake.nix.
  xdg.configFile."mango-host".source = config.lib.file.mkOutOfStoreSymlink "${mango}/hosts/${host}";
}
