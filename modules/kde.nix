{ nixpkgs-unstable, pkgs, ... }:
let
  unstablePackages = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # login is greetd (modules/greetd.nix); plasma is kept as the fallback session it offers
  services.desktopManager.plasma6.enable = true;

  environment.plasma6.excludePackages = with unstablePackages.kdePackages; [
    kate # text editor
    elisa # music player
    okular # document viewer / pdf reader
    konsole # terminal emulator
    kcalc # calculator
  ];
}
