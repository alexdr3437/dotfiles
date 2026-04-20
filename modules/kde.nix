{ pkgs, ... }:
{
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kate # text editor
    elisa # music player
    okular # document viewer / pdf reader
    konsole # terminal emulator
    kcalc # calculator
  ];
}
