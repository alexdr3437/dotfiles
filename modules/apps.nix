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

  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  services.actual = {
    enable = true;
    settings.port = 5006;
  };

  systemd.services.actual-tailscale-serve = {
    description = "Expose Actual through Tailscale HTTPS";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" "actual.service" ];
    wants = [ "tailscaled.service" "actual.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:5006";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];

  environment.systemPackages = with pkgs; [
    wireshark
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
