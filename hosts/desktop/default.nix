{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/greetd.nix
    ../../modules/mango.nix
    ../../modules/dolphin.nix
    ../../modules/audio.nix
    ../../modules/networking.nix
    ../../modules/embedded-dev.nix
    ../../modules/dev-tools.nix
    ../../modules/gaming.nix
    ../../modules/nvidia.nix
    ../../modules/virtualisation.nix
    ../../modules/fonts.nix
    ../../modules/apps.nix
    ../../modules/actual-backup.nix
    ../../modules/torrents.nix
    ../../modules/tailscale.nix
    ../../modules/home-dns.nix
    ../../modules/dictation.nix
    ../../modules/llm.nix
    ../../modules/logitech.nix
    ../../modules/foldingathome.nix
    ../../modules/syncthing.nix
    ../../modules/receipt-ingest.nix
  ];

  # Actual Budget server: backed up by actual-backup.nix, served through home-dns.nix
  services.actual = {
    enable = true;
    settings.port = 5006;
  };

  # nvidia 610.57.04 does not build on 7.3 (dmem_cgroup_register_region API change)
  boot.kernelPackages = pkgs.linuxPackages_7_2;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.extra-substituters = [ "https://ghostty.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 36 * 1024; # 36 GiB, in MiB
    }
  ];

  # EPP pinned to performance, with no power-profiles-daemon: balance_performance doubles
  # fork cost and popup latency
  services.power-profiles-daemon.enable = false;
  systemd.tmpfiles.rules = [
    "w /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference - - - - performance"
  ];

  # attempt to fix desktop stuttering
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];
  boot.extraModprobeConfig = ''
    options nvidia_modeset disable_vrr_memclk_switch=1
  '';

  networking.hostName = "nixos-desktop";

  time.timeZone = "America/Toronto";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.segger-jlink.acceptLicense = true;

  nixpkgs.config.permittedInsecurePackages = [
    "segger-jlink-qt4-874"
  ];

  # shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # user account
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      # NetworkManager without a polkit prompt: Proton VPN's kill switch adds a connection on every connect
      "networkmanager"
      "docker"
      "dialout"
      "wireshark"
      "plugdev"
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

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  # autologin (modules/greetd.nix) types no password, so the keyring is unlocked by the
  # first gtklock unlock instead
  security.pam.services.gtklock.enableGnomeKeyring = true;

  system.stateVersion = "25.05"; # do not change this!
}
