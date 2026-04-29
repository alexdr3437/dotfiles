{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./terminal.nix
    ./neovim.nix
    ./zsh.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "alex";
  home.homeDirectory = "/home/alex";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # terminal / CLI
    btop
    ripgrep
    lazygit
    jq
    tldr
    htop
    neofetch
    scc
    hyperfine
    xxd
    p7zip
    parallel
    ydiff
    wget
    unzip
    xclip
    socat
    dig
    nmap
    meld
    powertop
    powerstat
    lm_sensors
    man-pages
    pywal
    yay
    stow
    typst

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

    # other
    postgresql
    sniffnet
    capstone
    gjs
    arandr
    fftw
    linuxKernel.packages.linux_6_12.cpupower
    linuxKernel.packages.linux_6_12.perf
  ];

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/alex/etc/profile.d/hm-session-vars.sh
  #
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
