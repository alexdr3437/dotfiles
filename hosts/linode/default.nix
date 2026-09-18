{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/linode-config.nix") ];

  networking.hostName = "linode";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "America/Toronto";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Add the public key used to administer the VPS before deploying the image.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL8t/syQrxBwqGDeciO+4KAycDGllBAjAgMliSYR4ofW alex@nixos-desktop"
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
  };

  services.tailscale.enable = true;

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];

  system.stateVersion = "26.05";
}
