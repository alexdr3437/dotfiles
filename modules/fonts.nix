{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.agave
    nerd-fonts.fira-code
    noto-fonts # Noto Sans, the GTK UI font (home/mango.nix); came with Plasma before
  ];
}
