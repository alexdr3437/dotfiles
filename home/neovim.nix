{ pkgs, ... }:
{
  home.file.".config/nvim".source = ../files/dotfiles/nvim;

  home.packages = with pkgs; [
    nixfmt-rfc-style
    nixd
  ];
}
