{ pkgs, ... }:
{
  services.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma6.enable = true;
}
