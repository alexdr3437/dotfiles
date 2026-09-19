{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.config = {
    segger-jlink = {
      acceptLicense = true;
    };
    permittedInsecurePackages = [ "segger-jlink-qt4-874" ];
  };

  users.groups.plugdev = { };

  environment.systemPackages = with pkgs; [
    nrf-command-line-tools
    segger-jlink
    nrfconnect
    openocd
    probe-rs-tools
    gcc-arm-embedded
    picocom
    libftdi1
    nrfutil
    inputs.hw_db_interface.packages.${pkgs.stdenv.hostPlatform.system}.default
    wl-clipboard
    vault
  ];

  services.vault = {
    enable = true;
    dev = true;
    devRootTokenID = "root";
  };

  systemd.services.vault.postStart = lib.mkAfter ''
    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN=root

    until ${pkgs.vault}/bin/vault status >/dev/null 2>&1; do
      sleep 0.1
    done

    ${pkgs.vault}/bin/vault secrets enable transit
  '';

  environment.sessionVariables = {
    VAULT_ADDR = "http://127.0.0.1:8200";
    VAULT_TOKEN = "root";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1366", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="c251", ATTRS{idProduct}=="f001", MODE="0660", GROUP="plugdev"

    # Nordic Semiconductor (nrfutil)
    ACTION!="add", SUBSYSTEM!="usb_device", GOTO="nrf_rules_end"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1915", MODE="0666"
    KERNEL=="ttyACM[0-9]*", SUBSYSTEM=="tty", SUBSYSTEMS=="usb", ATTRS{idVendor}=="1915", MODE="0666", ENV{NRF_CDC_ACM}="1"
    LABEL="nrf_rules_end"

    # Prevent ModemManager from grabbing nRF CDC ACM devices
    ENV{NRF_CDC_ACM}=="1", ENV{ID_MM_CANDIDATE}="0", ENV{ID_MM_DEVICE_IGNORE}="1"

    # wisprflow
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess", GROUP="input", MODE="0660"
    SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess", GROUP="input", MODE="0660"
  '';
}
