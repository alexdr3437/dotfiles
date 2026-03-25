{ pkgs, ... }: {
  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.FastConnectable = true;
    settings.Policy.AutoEnable = true;
  };

  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    blueman
    bluez
    networkmanagerapplet
  ];
}
