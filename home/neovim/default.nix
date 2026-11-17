{ pkgs, inputs, ... }:
let
  # `import`, not `legacyPackages`: nixvim's pkgs need allowUnfree for copilot-language-server
  u = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  # plugins come from nixvim's nixpkgs, consumed as `{ nvimPkgs, ... }`
  _module.args.nvimPkgs = u;

  imports = [
    ./options.nix
    ./keymaps.nix
    ./autocmds.nix
    ./lsp.nix
    ./lspmem.nix
    ./plugins
  ];

  programs.nixvim = {
    enable = true;

    nixpkgs.pkgs = u;

    package = inputs.neovim-nightly.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
}
