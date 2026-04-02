{ pkgs, ... }:
{
  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  programs.appimage.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    fuse
  ];

  services.printing.enable = true;

  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  environment.systemPackages = with pkgs; [
    (brave.override {
      commandLineArgs = [
        "--disable-gpu-compositing"
      ];
    })
    wireshark
  ];
}
