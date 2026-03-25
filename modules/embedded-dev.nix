{ pkgs, ... }: {
  nixpkgs.config = {
    segger-jlink = { acceptLicense = true; };
    permittedInsecurePackages = [ "segger-jlink-qt4-810" ];
  };

  users.groups.plugdev = { };

  environment.systemPackages = with pkgs; [
    nrf-command-line-tools
    segger-jlink
    nrfconnect
    openocd
    probe-rs
    gcc-arm-embedded
    picocom
    libftdi1
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1366", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", MODE="0666", GROUP="plugdev"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="c251", ATTRS{idProduct}=="f001", MODE="0660", GROUP="plugdev"
  '';
}
