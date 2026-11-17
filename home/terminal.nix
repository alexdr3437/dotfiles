{
  nixpkgs-unstable,
  inputs,
  pkgs,
  config,
  ...
}:
let
  unstablePackages = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Zellij from upstream main (input zellij-src): nixpkgs's recipe, source and lockfile swapped
  zellij-compiled = unstablePackages.zellij-unwrapped.overrideAttrs (old: {
    version =
      (builtins.fromTOML (builtins.readFile "${inputs.zellij-src}/Cargo.toml")).workspace.package.version;
    src = inputs.zellij-src;
    cargoDeps = unstablePackages.rustPlatform.importCargoLock {
      lockFile = "${inputs.zellij-src}/Cargo.lock";
    };
  });
  # `zellij terminal` dlopens these at runtime; put on RUNPATH in a separate step, so no recompile
  zellij =
    unstablePackages.runCommand "zellij-${zellij-compiled.version}"
      {
        inherit (zellij-compiled) version meta;
        nativeBuildInputs = [ unstablePackages.patchelf ];
      }
      ''
        cp -r ${zellij-compiled} $out
        chmod -R u+w $out
        patchelf --add-rpath ${
          unstablePackages.lib.makeLibraryPath (
            with unstablePackages;
            [
              wayland # libwayland-client, libwayland-egl, libwayland-cursor
              libxkbcommon # also libxkbcommon-x11
              libGL # libglvnd: libEGL.so.1 dispatching to /run/opengl-driver
              fontconfig # system font discovery
              libx11
              libxcursor
              libxi
              libxrandr
            ]
          )
        } $out/bin/zellij
      '';
in
{
  home.packages = with pkgs; [
    btop
    ripgrep
    lazygit
    jq
    tldr
    htop
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
    unstablePackages.typst
    zellij
    unstablePackages.pi-coding-agent # state lives in ~/.pi/agent, not managed here
    (yazi.override {
      _7zz = _7zz-rar; # Support for RAR extraction
    })
    fastfetch
    ncdu
    pv
  ];

  programs.ghostty = {
    enable = true;
    package = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;
    enableZshIntegration = true;
    settings = {
      async-backend = "epoll";
      font-size = 10;
      background-opacity = 0.95;
      mouse-scroll-multiplier = 1;
      keybind = [
        "ctrl+enter=unbind"
      ];
      # From github.com/sahaj-b/cursor-shaders
      custom-shader = [
        "${config.xdg.configHome}/ghostty/shaders/cursor_warp.glsl"
        "${config.xdg.configHome}/ghostty/shaders/ripple_cursor.glsl"
      ];
    };
  };

  xdg.configFile."ghostty/shaders".source = ../files/dotfiles/ghostty/shaders;

  home.activation.lazygitConfig = ''
    if [ -L "$HOME/.config/lazygit" ]; then
      rm "$HOME/.config/lazygit"
    fi

    mkdir -p "$HOME/.config/lazygit"

    if [ -L "$HOME/.config/lazygit/config.yml" ]; then
      rm "$HOME/.config/lazygit/config.yml"
    fi

    if [ ! -f "$HOME/.config/lazygit/config.yml" ]; then
      cp "${../files/dotfiles/lazygit/config.yml}" "$HOME/.config/lazygit/config.yml"
      chmod u+w "$HOME/.config/lazygit/config.yml"
    fi
  '';

  # live symlink into the checkout, so config edits need no rebuild
  xdg.configFile."zellij/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/files/dotfiles/zellij/config.kdl";

  # zellij-agent: prompt an agent about selected text. Its plugin and keybind are in config.kdl by hand.
  programs.zellij-agent.enable = true;
  # stable path to the current build, for the Super a bind in config.kdl
  xdg.dataFile."zellij-agent/package".source = config.programs.zellij-agent.package;
}
