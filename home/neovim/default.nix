{ pkgs, inputs, ... }:
let
  # Deliberately `import`, not `legacyPackages`: that instance is fixed at the
  # flake's own defaults and takes no `config`. nixvim pins its pkgs below, so
  # the host's `nixpkgs.config.allowUnfree` never reaches it -- and copilot.nix
  # pulls in copilot-language-server, which is unfree (GitHub Copilot License).
  # Matches the pattern already used in modules/llm.nix.
  u = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  # Plugin packages should come from the same nixpkgs nixvim itself uses, not
  # home-manager's. Set once here, consumed elsewhere as `{ nvimPkgs, ... }`.
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
