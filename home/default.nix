{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.zellij-agent.homeManagerModules.default
    ./hermes.nix
    ./mango.nix
    ./terminal.nix
    ./neovim
    ./zsh.nix
    ./editor.nix
  ];

  home.username = "alex";
  home.homeDirectory = "/home/alex";

  home.stateVersion = "25.05"; # do not change this!

  home.packages = with pkgs; [
    # GUI apps
    discord
    slack
    obsidian
    bitwarden-desktop
    spotify
    element-desktop
    vscode
    dbeaver-bin
    firefox
    brave
    zathura
    libreoffice-fresh
    vlc
    proton-vpn
    proton-vpn-cli

    # other
    postgresql
    sniffnet
    capstone
    gjs
    arandr
    fftw
    perf
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [
    "/home/alex/.cargo/bin"
    "/home/alex/.local/bin"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

}
