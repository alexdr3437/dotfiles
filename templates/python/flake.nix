{
  description = "Basic Python project, using uv";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python3;
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              python
              pkgs.uv
            ];

            shellHook = ''
              export UV_PYTHON_PREFERENCE=only-system
              export UV_PYTHON_DOWNLOADS=never
              export PYTHONPATH="${python.pkgs.tkinter}/${python.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
              export LD_LIBRARY_PATH="${
                pkgs.lib.makeLibraryPath [
                  pkgs.stdenv.cc.cc.lib
                  pkgs.zlib
                ]
              }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            '';
          };
        }
      );
    };
}
