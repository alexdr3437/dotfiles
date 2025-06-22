{
  description = "minimal rust flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.rustc
          pkgs.cargo
          pkgs.rust-analyzer
		  pkgs.pkg-config
          pkgs.gobject-introspection
          pkgs.gtk3
          pkgs.glib
        ];
      };

      packages.${system}.default = pkgs.rustPlatform.buildRustPackage {
        pname = "rust-project";
        version = "0.1.0";
        src = ./.;
      };
    };
}

