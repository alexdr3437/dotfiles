{
  nixpkgs-unstable,
  inputs,
  pkgs,
  config,
  ...
}:
let
  unstablePackages = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Zellij built from upstream main (flake input zellij-src) instead of the nixpkgs release:
  # nixpkgs's recipe with the source and lockfile swapped. `nix flake update zellij-src` moves it.
  # Config: files/dotfiles/zellij/config.kdl, linked below.
  zellij-compiled = unstablePackages.zellij-unwrapped.overrideAttrs (old: {
    version = (builtins.fromTOML (builtins.readFile "${inputs.zellij-src}/Cargo.toml")).workspace.package.version;
    src = inputs.zellij-src;
    cargoDeps = unstablePackages.rustPlatform.importCargoLock { lockFile = "${inputs.zellij-src}/Cargo.lock"; };
  });
  # The desktop app (`zellij terminal`, also what the runner entry and the session manager's
  # "open in a window" run) dlopens Wayland, EGL, xkbcommon and fontconfig at runtime. They are in
  # no global lib dir on NixOS, so it died silently; put them on the binary's RUNPATH. A separate
  # step over the compiled output, so the 15-minute compile is not redone for it.
  zellij = unstablePackages.runCommand "zellij-${zellij-compiled.version}"
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
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
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

  # ~/.config/zellij/config.kdl → files/dotfiles/zellij/config.kdl as a live symlink into the
  # checkout (like ~/.config/mango), so config edits need no rebuild. programs.zellij is off:
  # the config is plain KDL, not generated.
  xdg.configFile."zellij/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/files/dotfiles/zellij/config.kdl";

  # zellij-agent: select text in Neovim (<leader>i) or any pane, type or dictate a prompt.
  # The module (flake input) installs the package, the plugin and the Neovim add-on. With
  # programs.zellij off it adds nothing to the Zellij config: load_plugins and the keybind
  # (programs.zellij-agent.zellij.keybindsKdl) go in files/dotfiles/zellij/config.kdl by hand.
  programs.zellij-agent.enable = true;
  # Stable path to the current zellij-agent build, so the Super a bind in config.kdl can pass it
  # as the plugin's payload without a store path that goes stale on every update.
  xdg.dataFile."zellij-agent/package".source = config.programs.zellij-agent.package;
}
