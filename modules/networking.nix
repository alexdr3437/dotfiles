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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "alex" ];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  environment.systemPackages = with pkgs; [
    blueman
    bluez
    networkmanagerapplet
  ];
}
