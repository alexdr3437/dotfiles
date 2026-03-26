{ ... }:
{
  home.file.".config/kitty".source = ../files/dotfiles/kitty;
  home.file.".config/zellij".source = ../files/dotfiles/zellij;
  home.file.".zshrc".source = ../files/dotfiles/.zshrc;

  home.activation.lazygitConfig = ''
    if [ -L "$HOME/.config/lazygit" ]; then
      rm "$HOME/.config/lazygit"
    fi

    mkdir -p "$HOME/.config/lazygit"

    if [ -L "$HOME/.config/lazygit/config.yml" ]; then
      rm "$HOME/.config/lazygit/config.yml"
    fi

    if [ ! -f "$HOME/.config/lazygit/config.yml" ]; then
      cp "${../files/dotfiles/lazygit/config.yml}" "$HOME/.config/lazygit/config.yml"
      chmod u+w "$HOME/.config/lazygit/config.yml"
    fi
  '';
}
