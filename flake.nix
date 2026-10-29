{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    neovim-nightly = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # don't follow nixpkgs, ghostty pins its own zig toolchain
    ghostty.url = "github:ghostty-org/ghostty/v1.4.0";

    voxtype.url = "github:peteonrails/voxtype/v1.1.1-rc2";

    hw_db_interface.url = "git+ssh://git@github.com/Mesomat-Inc/hw_db_interface.git?ref=main";
    marc.url = "git+ssh://git@github.com/Mesomat-Inc/tires-firmware-rs.git?dir=device-manager/tools/marc&ref=dev";
    tires-firmware.url = "git+ssh://git@github.com/Mesomat-Inc/tires-firmware-rs.git?ref=dev&submodules=1";
    gateway-certs.url = "git+ssh://git@github.com/Mesomat-Inc/gateway-certificate-signing.git";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nixvim,
      neovim-nightly,
      ...
    }@inputs:
    {
      lib = import ./lib inputs;

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs-unstable; };
        modules = [
          { _module.args = { inherit inputs; }; }

          ./hosts/desktop
          home-manager.nixosModules.home-manager

          {
            nixpkgs.overlays = [
              (final: prev: {
                zed-editor = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.zed-editor;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit nixpkgs-unstable;
              inherit inputs;
            };
            home-manager.users.alex = import ./home;
          }
        ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nixpkgs-unstable; };
        modules = [
          { _module.args = { inherit inputs; }; }

          ./hosts/laptop
          home-manager.nixosModules.home-manager

          {
            nixpkgs.overlays = [
              (final: prev: {
                zed-editor = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.zed-editor;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit nixpkgs-unstable;
              inherit inputs;
            };
            home-manager.users.alex = import ./home;
          }
        ];
      };

      nixosConfigurations.linode = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/linode ];
      };

      nixosConfigurations.linode-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/linode/image.nix ];
      };

      packages.x86_64-linux.linode-image =
        inputs.self.nixosConfigurations.linode-image.config.system.build.linodeImage;

      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust template";
        };
      };
    };
}
