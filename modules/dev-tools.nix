{ pkgs, ... }:
{
  environment.localBinInPath = true;

  environment.interactiveShellInit = ''
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:"
    export CPATH="${pkgs.linuxHeaders}/include:$CPATH"
  '';

  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    cmake
    git
    gdb
    pkg-config
    openssl
    openssl.dev
    linuxHeaders
  ];
}
