# conform.nvim: format on save, plus <leader>f to format on demand.
{ ... }:
{
  programs.nixvim = {
    plugins.conform-nvim = {
      enable = true;

      autoInstall.enable = false;

      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];

          # lsp.nix also gives nixd nixfmt, for vim.lsp.buf.format()
          nix = [ "nixfmt" ];

          # runs in order. No ruff `preview` formatting: it breaks polars chains
          python = [
            "ruff_fix"
            "ruff_format"
            "ruff_organize_imports"
          ];
        };

        # failures are still in :ConformInfo
        notify_on_error = false;

        # async on save; no LSP formatting for the filetypes below
        format_on_save = ''
          function(bufnr)
            local no_lsp_format = {
              c = true,
              cpp = true,
              json = true,
              javascript = true,
              typescriptreact = true,
            }

            return {
              -- generous: three ruff passes on python
              timeout_ms = 2000,
              lsp_format = no_lsp_format[vim.bo[bufnr].filetype] and "never" or "fallback",
            }
          end
        '';
      };
    };

    keymaps = [
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>f";
        action.__raw = ''
          function()
            require("conform").format({ async = true, lsp_format = "fallback" })
          end
        '';
        options.desc = "[F]ormat buffer";
      }
    ];
  };
}
