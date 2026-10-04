{ pkgs, lib, ... }:

let
  steamOffloadDesktop = pkgs.runCommand "steam-nvidia-offload-desktop" { } ''
    mkdir -p $out/share/applications
    sed 's#^Exec=#Exec=nvidia-offload #' ${pkgs.steam}/share/applications/steam.desktop > $out/share/applications/steam.desktop
  '';

  prismLauncherNvidia = pkgs.writeShellScriptBin "prismlauncher" ''
    exec nvidia-offload ${pkgs.prismlauncher}/bin/prismlauncher "$@"
  '';
in
{
  programs.steam.enable = true;

  hardware.nvidia.prime.offload = {
    enable = true;
    enableOffloadCmd = true;
  };

  environment.systemPackages = [
    pkgs.prismlauncher
    (lib.hiPrio prismLauncherNvidia)
    (lib.hiPrio steamOffloadDesktop)
  ];
}
