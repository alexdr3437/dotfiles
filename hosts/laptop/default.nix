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

  # TLP instead of power-profiles-daemon (ppd used to be driven by Plasma's powerdevil),
  # and the CPU policy lives here: balanced on wall power, power saver on battery. These are
  # TLP's own defaults, spelled out. (The desktop also drops ppd but pins EPP to performance.)
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      # The BIOS leaves ASPM off on the NVMe link though the drive and its root port both
      # support L1/L1.2; this enables it on every capable link (~1.5 W on battery). It has
      # to be TLP's setting: its default ("default") resets a pcie_aspm.policy= boot option
      # whenever TLP starts or the power source changes.
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";
      # RUNTIME_PM_ON_AC stays at TLP's default ("on"): the savings aren't wanted.
      # Don't USB-autosuspend the AX211's bluetooth half: TLP's suggestion for unstable
      # bluetooth, and this controller crashes (see bluetooth-watchdog below).
      USB_EXCLUDE_BTUSB = 1;
    };
  };

  # Docker on demand (docker.socket starts it on first use) instead of at every boot.
  # Containers with a restart policy (e.g. forwarder) then only come up once Docker runs.
  virtualisation.docker.enableOnBoot = false;

  # The lid is mango's: files/dotfiles/mango/hosts/laptop/mango.conf binds fold/unfold
  # to monitors.sh (battery → suspend, AC → lock + panel off). logind would otherwise
  # suspend on top of that.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # The Intel AX211 bluetooth controller throws "Hardware error 0x0c" on BLE reconnects
  # (an Adv360 Pro reconnect loop logged ~12k of them in one boot). If the keyboard keeps
  # dropping with these, remove every device in bluetoothctl, then re-pair and trust them:
  # that stopped a crash every ~30 s on Nov 6 2026 where no config change did.
  # Two ways it breaks:
  # - wedged: an LE command fails ("Opcode 0x200e failed: -16", "tx timeout") and the
  #   kernel never reconnects anything until the adapter is power cycled;
  # - gone: the controller crashes, the kernel's ACPI reset never brings it back and it
  #   drops off USB (usb 3-10 "device not accepting address, error -71"), so there's no
  #   hci0 to power cycle. It stayed dead for 2.5 days until a reboot (Nov 2026).
  # Every 30 s: wedged → bluetoothctl power cycle; gone for a minute → rebind the xHCI
  # controller it sits on (00:14.0, shared with the webcam and USB-A ports) unless a USB
  # drive is attached there; still gone after two rebinds → notify to reboot.
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
              echo "bluetooth wedged ($line), power cycling adapter"
              sleep 10 # let the kernel finish its own reset first
              bluetoothctl power off
              sleep 2
              bluetoothctl power on
              cycled=$(date +%s)
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
  hardware.cpu.intel.updateMicrocode = true; # Assuming you have an Intel CPU

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
