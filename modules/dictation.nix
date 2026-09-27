{ inputs, pkgs, ... }:
let
  voxtype = inputs.voxtype.packages.${pkgs.system}.vulkan;
in
{
  environment.systemPackages = [
    voxtype
    pkgs.wtype
    pkgs.wl-clipboard
    pkgs.dotool
  ];

  users.users.alex.extraGroups = [
    "input"
  ];

  systemd.user.services.voxtype = {
    description = "Voxtype voice dictation";

    wantedBy = [
      "graphical-session.target"
    ];

    after = [
      "graphical-session.target"
    ];

    path = with pkgs; [
      dotool
      ydotool
      wl-clipboard
      wtype
      which
    ];

    environment = {
      VOXTYPE_VULKAN_DEVICE = "nvidia";
      XDG_RUNTIME_DIR = "%t";
      WAYLAND_DISPLAY = "wayland-0";
      RUST_LOG = "voxtype=debug";
    };

    serviceConfig = {
      ExecStart = "${voxtype}/bin/voxtype daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  boot.kernelModules = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", MODE="0660"
  '';
}
