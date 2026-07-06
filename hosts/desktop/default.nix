{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # ../../modules/hyprland.nix
    ../../modules/kde.nix
    ../../modules/audio.nix
    ../../modules/neovim.nix
    ../../modules/networking.nix
    ../../modules/embedded-dev.nix
    ../../modules/dev-tools.nix
    ../../modules/gaming.nix
    ../../modules/nvidia.nix
    ../../modules/virtualisation.nix
    ../../modules/fonts.nix
    ../../modules/apps.nix
    ../../modules/torrents.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 36 * 1024; # 32 GB in MiB
    }
  ];

  networking.hostName = "nixos-desktop";

  time.timeZone = "America/Toronto";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.segger-jlink.acceptLicense = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
    "segger-jlink-qt4-874"
  ];

  # shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.groups.inputs = { };
  users.groups.media = { };

  # user account
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "dialout"
      "wireshark"
      "plugdev"
      "inputs"
      "media"
    ];
    packages = with pkgs; [ tree ];
    shell = pkgs.zsh;
  };

  fileSystems."/srv/media" = {
    device = "/dev/disk/by-uuid/a3382bbe-a761-491c-8f78-a198f9cc75b1";
    fsType = "ext4";
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

  services.fwupd.enable = true;

  services.openssh.enable = true;

  systemd.services.systemd-rfkill.enable = false;
  systemd.sockets.systemd-rfkill.enable = false;

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

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  system.stateVersion = "25.05"; # do not change this!
}
