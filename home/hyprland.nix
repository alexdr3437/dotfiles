{ ... }:
{
  home.file.".config/hypr".source = ../files/dotfiles/hypr;
  # for some reason, walker complains about the readonly file system, so copy the files instead of symlinking them
  home.activation.walkerConfig = ''
    rm -rf "$HOME/.config/walker"
    cp -r "${../files/dotfiles/walker}" "$HOME/.config/walker"
    chmod -R u+w "$HOME/.config/walker"
  '';
  home.file.".config/eww".source = ../files/dotfiles/eww;
}
