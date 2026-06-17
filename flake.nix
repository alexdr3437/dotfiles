{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hw_db_interface.url = "git+ssh://git@github.com/Mesomat-Inc/hw_db_interface.git?ref=main";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:
    {
      lib = import ./lib inputs;

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { _module.args = { inherit inputs; }; }

          ./hosts/desktop
          home-manager.nixosModules.home-manager

          {
            nixpkgs.overlays = [
              (final: prev: {
                kitty = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.kitty;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alex = import ./home;
          }
        ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { _module.args = { inherit inputs; }; }

          ./hosts/laptop
          home-manager.nixosModules.home-manager

          {
            nixpkgs.overlays = [
              (final: prev: {
                kitty = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.kitty;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alex = import ./home;
          }
        ];
      };

      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust template";
        };
      };
    };
}
