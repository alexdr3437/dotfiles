{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/greetd.nix
    ../../modules/mango.nix # the session greetd boots into; config in files/dotfiles/mango
    ../../modules/dolphin.nix
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

  # TLP instead of power-profiles-daemon: balanced on AC, power saver on battery
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      # ASPM on every capable link (the BIOS leaves it off on the NVMe, ~1.5 W); a boot
      # option would be reset by TLP
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";
      # no USB autosuspend for the AX211's bluetooth half, it crashes (bluetooth-watchdog below)
      USB_EXCLUDE_BTUSB = 1;
    };
  };

  # Docker on demand (docker.socket), not at every boot
  virtualisation.docker.enableOnBoot = false;

  # mango handles the lid (hosts/laptop/mango.conf, monitors.sh); logind must not suspend too
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # The AX211 bluetooth controller crashes on BLE reconnects ("Hardware error 0x0c").
  # Every 30 s: wedged (LE command error, powered, nothing connected) → power cycle;
  # gone from USB for a minute → rebind its xHCI controller (00:14.0); after two rebinds → notify.
  # If a device keeps dropping: remove, re-pair and trust it in bluetoothctl.
  systemd.services.bluetooth-watchdog =
    let
      xhci = "0000:00:14.0";
      notify = msg: ''
        runuser -u alex -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u alex)/bus" \
          notify-send -u critical -a bluetooth "Bluetooth" "${msg}" || true
      '';
    in
    {
      description = "Recover the bluetooth adapter when it wedges or drops off USB";
      after = [ "bluetooth.service" ];
      wants = [ "bluetooth.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        systemd
        gnugrep
        bluez
        coreutils
        findutils
        util-linux # runuser
        libnotify
      ];
      script = ''
        dev=/sys/bus/pci/devices/${xhci}
        drv=/sys/bus/pci/drivers/xhci_hcd
        since=$(date +%s) cycled=0 missing=0 tries=0 reset=0 told=0
        while sleep 30; do
          now=$(date +%s)
          if ls /sys/class/bluetooth/hci* >/dev/null 2>&1; then
            [ $tries -gt 0 ] && echo "bluetooth adapter is back after $tries USB reset(s)"
            missing=0 tries=0 told=0
            line=$(journalctl -k -q -o cat --since "@$since" \
              | grep -m1 -E 'Bluetooth: hci[0-9]+: (Opcode 0x200e failed|command 0x[0-9a-f]+ tx timeout|Reset after hardware error failed)' || true) # no match is the normal case; the unit runs under set -e
            since=$now
            if [ -n "$line" ] && [ $((now - cycled)) -ge 60 ]; then
              sleep 10 # let the kernel finish its own reset, and devices reconnect
              # only a wedge leaves the adapter powered with nothing connected
              if ! bluetoothctl show | grep -q 'Powered: yes'; then
                echo "bluetooth error ($line), but the adapter is powered off; leaving it"
              elif bluetoothctl devices Connected | grep -q '^Device '; then
                echo "bluetooth error ($line), but devices are connected; not power cycling"
              else
                echo "bluetooth wedged ($line), nothing connected, power cycling adapter"
                bluetoothctl power off
                sleep 2
                bluetoothctl power on
                cycled=$(date +%s)
              fi
            fi
            continue
          fi
          since=$now
          missing=$((missing + 1))
          [ $missing -lt 2 ] && continue # not just a resume blip
          [ $((now - reset)) -lt 300 ] && continue
          if [ $tries -ge 2 ]; then
            if [ $told -eq 0 ]; then
              echo "bluetooth adapter still missing after $tries USB resets, giving up until it returns"
              ${notify "Adapter is gone and USB resets didn't bring it back. Reboot to recover."}
              told=1
            fi
            continue
          fi
          if [ -n "$(find "$dev"/ -maxdepth 6 -name 'host[0-9]*' -print -quit 2>/dev/null)" ]; then
            if [ $told -eq 0 ]; then
              echo "bluetooth adapter missing, but a USB drive is on ${xhci}; not resetting"
              ${notify "Adapter is gone. Not resetting USB while a drive is plugged in; unplug it or reboot."}
              told=1
            fi
            continue
          fi
          tries=$((tries + 1)) reset=$now
          echo "bluetooth adapter missing for $((missing * 30))s, rebinding xhci ${xhci} (attempt $tries)"
          echo ${xhci} > $drv/unbind
          sleep 2
          echo ${xhci} > $drv/bind
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
  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "nixos-laptop";

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
      "networkmanager" # see the desktop: Proton VPN's kill switch needs it
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
