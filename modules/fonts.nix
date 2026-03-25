{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.agave
    nerd-fonts.fira-code
  ];
}
