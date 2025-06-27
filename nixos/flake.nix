{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-25.05 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
	
	home-manager.url = "github:nix-community/home-manager/release-25.05";
	home-manager.inputs.nixpkgs.follows = "nixpkgs";

    rust-workspace.url = "git+ssh://git@github.com/Mesomat-Inc/rust-workspace.git?ref=development";
	decoder.url = "git+ssh://git@github.com/Mesomat-Inc/decoder.git?ref=development";
	hw_db_interface.url = "git+ssh://git@github.com/Mesomat-Inc/hw_db_interface.git?ref=development";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
    # Please replace my-nixos with your hostname
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          _module.args = {
            inputs = inputs;
          };
        }
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix
		home-manager.nixosModules.home-manager {
			home-manager.useGlobalPkgs = true;
			home-manager.useUserPackages = true;
			home-manager.users.alex = ./home.nix;
		}
		({ pkgs, ... }: {
          environment.systemPackages = [
            inputs.decoder.packages.${pkgs.system}.default
            inputs.hw_db_interface.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
