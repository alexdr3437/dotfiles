{ nixpkgs-unstable, pkgs, ... }:
let
  unstablePackages = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  services.ollama = {
    enable = true;
    package = unstablePackages.ollama-cuda;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "16384";
    };
  };
}
