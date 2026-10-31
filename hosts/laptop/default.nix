{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kde.nix
    ../../modules/mango.nix # "Mango" session beside plasma in sddm; config in files/dotfiles/mango
    ../../modules/audio.nix
    ../../modules/networking.nix
    ../../modules/embedded-dev.nix
    ../../modules/dev-tools.nix
    ../../modules/virtualisation.nix
    ../../modules/fonts.nix
    ../../modules/apps.nix
    ../../modules/tailscale.nix
  ];

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

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # TLP instead of power-profiles-daemon, so Plasma's profile setting (powerdevilrc) is inert
  # and the CPU policy lives here: balanced on wall power, power saver on battery. These are
  # TLP's own defaults, spelled out. (The desktop has the same intent in hosts/desktop.)
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
    };
  };

  # The lid is mango's: files/dotfiles/mango/hosts/laptop/mango.conf binds fold/unfold
  # to monitors.sh (battery → suspend, AC → lock + panel off). logind would otherwise
  # suspend on top of that. Applies to the plasma session too.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # The Intel AX211 bluetooth controller throws "Hardware error 0x0c" on BLE
  # reconnects, and eventually an LE connection cancel fails ("Opcode 0x200e
  # failed: -16"). After that the kernel never reconnects anything until the
  # adapter is power cycled, so do that automatically.
  systemd.services.bluetooth-watchdog = {
    description = "Power cycle the bluetooth adapter when it wedges";
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      systemd
      gnugrep
      bluez
      coreutils
    ];
    script = ''
      last=0
      journalctl -kf -n0 -o cat \
        | grep --line-buffered -E 'Bluetooth: hci[0-9]+: (Opcode 0x200e failed|command 0x[0-9a-f]+ tx timeout|Reset after hardware error failed)' \
        | while read -r line; do
            now=$(date +%s)
            [ $((now - last)) -lt 60 ] && continue
            echo "bluetooth wedged ($line), power cycling adapter"
            sleep 10 # let the kernel finish its own reset first
            bluetoothctl power off
            sleep 2
            bluetoothctl power on
            last=$(date +%s)
          done
    '';
    serviceConfig.Restart = "always";
  };

  boot.kernelParams = [
    "python_backtrace=1" # Helps logs if it still crashes
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true; # Assuming you have an Intel CPU

  networking.hostName = "nixos-laptop";

  time.timeZone = "America/Toronto";

  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
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

  services.fwupd.enable = true;

  services.openssh.enable = true;

  system.stateVersion = "25.05"; # do not change this!
}
