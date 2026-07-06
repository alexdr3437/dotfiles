{ pkgs, ... }:
{
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  services.flatpak.enable = true;

  programs.appimage.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    fuse
  ];

  services.printing.enable = true;

  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  environment.systemPackages = with pkgs; [
    wireshark
    parted
    gptfdisk
    e2fsprogs
    util-linux
    rsync
    nvme-cli
    smartmontools
  ];
}
