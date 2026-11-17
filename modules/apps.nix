{ pkgs, ... }:
{
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  services.flatpak.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    fuse
  ];

  services.printing.enable = true;

  # the module creates the wireshark group and the dumpcap wrapper
  programs.wireshark.enable = true;

  # sniffnet captures itself, so its own binary needs the capabilities; wireshark group only
  security.wrappers.sniffnet = {
    owner = "root";
    group = "wireshark";
    permissions = "u+rx,g+rx";
    capabilities = "cap_net_raw,cap_net_admin+eip";
    source = "${pkgs.sniffnet}/bin/sniffnet";
  };

  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    e2fsprogs
    util-linux
    rsync
    nvme-cli
    smartmontools
    calibre
    bruno
    zotero
  ];

  # the module opens 53317 in the firewall
  programs.localsend.enable = true;
}
