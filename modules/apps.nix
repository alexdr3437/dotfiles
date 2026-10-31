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

  # wireshark through its module, not just the package: this creates the wireshark group (the
  # hosts put alex in it) and the dumpcap capture wrapper. Without it the group did not exist.
  programs.wireshark.enable = true;

  # sniffnet (home/default.nix) captures with libpcap itself, so unlike wireshark (dumpcap) it
  # needs the capabilities on its own binary: "Attempt to create packet socket failed -
  # CAP_NET_RAW may be required" otherwise. /run/wrappers/bin is ahead of the user profile on
  # PATH, so a plain `sniffnet` (the bar's network widget) gets this wrapper. wireshark group only.
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

  services.actual = {
    enable = true;
    settings.port = 5006;
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
}
