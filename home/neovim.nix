{ pkgs, ... }:
{
  home.file.".config/nvim".source = ../files/dotfiles/nvim;

  home.packages = with pkgs; [
    nodejs
    nixfmt-rfc-style
    nixd
  ];
}
