{
  pkgs,
  nixpkgs-unstable,
  inputs,
  ...
}:
let
  u = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  gateway-console = inputs.tires-firmware.packages.${pkgs.stdenv.hostPlatform.system}.gateway-console;
in
{
  environment.localBinInPath = true;

  environment.shellAliases.gcon = "gateway-console";

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
    jujutsu # Provides the `jj` command.
    gdb
    pkg-config
    openssl
    openssl.dev
    linuxHeaders
    u.just
    u.just-lsp
    gateway-console
  ];
}
