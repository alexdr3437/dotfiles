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

          # first available wins: ruff, except in a project with a .style.yapf
          python = {
            __unkeyed-1 = "ruff_format";
            __unkeyed-2 = "yapf";
            stop_after_first = true;
          };
        };

        formatters = {
          # set `line-length` per project under [tool.ruff]. Do not enable `preview`
          # formatting: it breaks polars chains.
          ruff_format.condition.__raw = ''
            function(_, ctx)
              return vim.fs.root(ctx.dirname, { ".style.yapf" }) == nil
            end
          '';

          # yapf reads stdin, so run it from the directory holding .style.yapf or it is not found
          yapf.cwd.__raw = ''
            require("conform.util").root_file({
              ".style.yapf",
              "setup.cfg",
              "pyproject.toml",
            })
          '';
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
              -- generous: yapf starts a python interpreter every time
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
