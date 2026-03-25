{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hyprland.nix
    ../../modules/audio.nix
    ../../modules/neovim.nix
    ../../modules/networking.nix
    ../../modules/embedded-dev.nix
    ../../modules/dev-tools.nix
    ../../modules/gaming.nix
    ../../modules/virtualisation.nix
    ../../modules/fonts.nix
    ../../modules/apps.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  time.timeZone = "America/Toronto";

  nixpkgs.config.allowUnfree = true;

  # shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # user account
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "dialout"
      "wireshark"
      "plugdev"
    ];
    packages = with pkgs; [ tree ];
    shell = pkgs.zsh;
  };

  # passwordless nixos-rebuild
  security.sudo.extraRules = [
    {
      users = [ "alex" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';

  services.openssh.enable = true;

  # host-specific SSH tunnel
  systemd.services = {
    ssh-tunnel = {
      description = "remote access tunnel to mesomat@";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.openssh}/bin/ssh \
            -o ServerAliveInterval=60 \
            -o StrictHostKeyChecking=no \
            -o ExitOnForwardFailure=yes \
            -nNTvvv -R 40202:localhost:22 mesomat@device-manager.mesomat.org
        '';
        Restart = "always";
        RestartSec = 5;
        User = "alex";
      };
    };
  };

  system.stateVersion = "25.05"; # do not change this!
}
