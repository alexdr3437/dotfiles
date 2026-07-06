{ pkgs, ... }:
{
  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.FastConnectable = true;
    settings.Policy.AutoEnable = true;
  };

  services.blueman.enable = true;

  # services.resolved = {
  #   enable = true;
  #
  #   settings.Resolve = {
  #     DNS = [
  #       "45.90.28.0#9be4fc.dns.nextdns.io"
  #       "45.90.30.0#9be4fc.dns.nextdns.io"
  #       "2a07:a8c0::#9be4fc.dns.nextdns.io"
  #       "2a07:a8c1::#9be4fc.dns.nextdns.io"
  #     ];
  #
  #     DNSOverTLS = false;
  #   };
  # };
  #
  # networking.networkmanager.dns = "systemd-resolved";

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    blueman
    bluez
    networkmanagerapplet
  ];
}
