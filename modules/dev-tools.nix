{ pkgs, ... }: {
  environment.localBinInPath = true;

  environment.interactiveShellInit = ''
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:"
    export CPATH="${pkgs.linuxHeaders}/include:$CPATH"
  '';

  nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    cmake
    git
    gdb
    pkg-config
    clang-tools
    rustup
    nodejs
    yarn
    zig
    zls
    uv
    maturin
    lua-language-server
    openssl
    openssl.dev
    linuxHeaders
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];
}
