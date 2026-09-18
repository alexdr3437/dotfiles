{ pkgs, inputs, ... }:
let
  u = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.nixvim = {
    enable = true;

    nixpkgs.pkgs = u;

    package = inputs.neovim-nightly.packages.${pkgs.stdenv.hostPlatform.system}.default;

    plugins.lspconfig.enable = true;
    lsp.servers = {
      rust_analyzer.enable = true;
      clangd.enable = true;
      lua_ls.enable = true;
      nixd.enable = true;
      just.enable = true;
    };

    plugins = {

      telescope.enable = true;

      treesitter = {
        enable = true;
        highlight.enable = true;
        indent.enable = true;
      };

      lualine.enable = true;

      gitsigns.enable = true;

      web-devicons.enable = true;
    };
  };
}
