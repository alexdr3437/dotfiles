# conform.nvim: format on save, plus <leader>f to format on demand.
#
# Formatter binaries come from `autoInstall`, which reads formatters_by_ft and
# puts the matching nixpkgs package on the wrapped PATH -- so ruff/stylua/yapf/
# nixfmt never have to be repeated in home.packages, and never leak onto the
# login shell's PATH either.
{ ... }:
{
  programs.nixvim = {
    plugins.conform-nvim = {
      enable = true;

      autoInstall.enable = true;

      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];

          # nixd is enabled in lsp.nix but not handed a formatting command, so
          # nix files have no LSP formatter to fall back to. Do it here instead.
          nix = [ "nixfmt" ];

          # Python is picked per project, not globally: conform walks this list
          # and takes the first formatter that is *available*, and a formatter
          # whose `condition` returns false counts as unavailable. So ruff wins
          # everywhere except in a project carrying a .style.yapf, where it
          # stands down (see `formatters.ruff_format` below) and yapf runs.
          #
          # The trigger is the style file itself, which keeps the choice next to
          # the code rather than in here: add .style.yapf to a project to opt it
          # back into yapf, delete it to get ruff.
          python = {
            __unkeyed-1 = "ruff_format";
            __unkeyed-2 = "yapf";
            stop_after_first = true;
          };
        };

        formatters = {
          # ruff_format keeps a parenthesised method chain exploded one call per
          # line whenever it does not fit on a single line -- which is what makes
          # it readable for polars. That only works at a sane line length; a huge
          # one tells it the chain fits, and it collapses back to one line.
          # Configure it per project with `line-length` under [tool.ruff].
          #
          # NOTE: do not turn on ruff's `preview` formatting. Its fluent style
          # breaks before the first attribute, so a polars chain gains a line
          # containing nothing but `pl`.
          ruff_format.condition.__raw = ''
            function(_, ctx)
              return vim.fs.root(ctx.dirname, { ".style.yapf" }) == nil
            end
          '';

          # conform hands yapf the buffer on stdin with no filename attached.
          # With no file to look at, yapf searches for .style.yapf upward from
          # its own process cwd -- which is wherever nvim was launched, not
          # where the file lives. Open a python file from outside its project
          # and the style file is never seen, and yapf quietly falls back to
          # pep8 (column_limit 79).
          #
          # Anchoring cwd to the directory that actually holds the style file
          # restores the search yapf would have done from the file itself.
          yapf.cwd.__raw = ''
            require("conform.util").root_file({
              ".style.yapf",
              "setup.cfg",
              "pyproject.toml",
            })
          '';
        };

        # Failures are still recorded in :ConformInfo; a popup on every save
        # that happens to fail is noise.
        notify_on_error = false;

        # Ran asynchronously on save. Returns the table conform.format() gets.
        #
        # `lsp_fallback = true/false` is the spelling conform used to take; it
        # now wants `lsp_format = "fallback"/"never"` and warns on the old one.
        #
        # The filetypes below have no house style worth imposing on every save,
        # so no LSP formatting for them. A formatter listed in formatters_by_ft
        # would still run -- none of them have one, which is the point.
        #
        # NOTE: the lua config spelled two of these `js` and `tsx`. Neither is a
        # real neovim filetype (they are `javascript` and `typescriptreact`), so
        # those two entries never matched anything. Fixed here.
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
              -- Generous, because yapf still runs in .style.yapf projects and
              -- spawns a fresh python interpreter every time -- interpreter
              -- startup alone can eat a 500ms budget, which is what the lua
              -- config allowed and what made saves fail with "timeout".
              -- ruff needs none of this; it is a few milliseconds.
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
