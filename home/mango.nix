{ config, pkgs, ... }:
{
  # popups + taskbar daemon (eww.yuck); the rest of the stack is in modules/mango.nix
  home.packages = [ pkgs.eww ];

  # ~/.config/mango → files/dotfiles/mango as a live symlink into the checkout,
  # not a store copy: theme.sh writes generated files next to the config
  # (theme.css, eww/_colors.scss, rofi-colors.rasi; gitignored there), and bar /
  # popup / css edits reload in place without a rebuild. See its README.md.
  # Packages (mango, waybar, swaync, gtklock, ...) come from modules/mango.nix;
  # jq is in home/default.nix.
  xdg.configFile."mango".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/files/dotfiles/mango";
}
