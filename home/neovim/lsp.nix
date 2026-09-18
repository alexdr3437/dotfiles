# Language servers, plus the LSP keymaps that nvim does not provide by default.
#
# Each server's `config` is the table handed to `vim.lsp.config()`, merged over
# whatever nvim-lspconfig already ships for that server -- so only the bits that
# differ from its defaults are spelled out. `cmd` and `filetypes` are omitted
# wherever the default is already right.
#
# Capabilities are NOT set here: plugins/completion.nix sets them once, globally,
# on the `*` pseudo-server.
{ ... }:
{
  programs.nixvim = {
    plugins.lspconfig.enable = true;

    lsp.servers = {
      # Rust.
      #
      # checkOnSave is off deliberately: cargo check on every write is what makes
      # rust-analyzer expensive in a big workspace. :LspMem (see lspmem.nix) is
      # there to keep an eye on the rest.
      rust_analyzer = {
        enable = true;
        config = {
          settings."rust-analyzer" = {
            cargo.allFeatures = false;
            checkOnSave = false;
            procMacro.enable = true;
          };
          flags.debounce_text_changes = 150;
        };
      };

      # C / C++.
      #
      # NOTE: the two --tweaks flags are carried over from the lua config, but
      # they look ineffective -- clangd's --tweaks takes the names of code
      # tweaks, not compiler flags, and silently ignores anything it does not
      # recognise. If the intent was to lift the error limit, that belongs in a
      # .clangd file as `CompileFlags: Add: [-ferror-limit=0]`.
      clangd = {
        enable = true;
        config = {
          cmd = [
            "clangd"
            "--background-index"
            "--clang-tidy"
            "--tweaks=-ferror-limit=0"
            "--tweaks=-ftemplate-backtrace-limit=0"
          ];
          filetypes = [
            "c"
            "cpp"
            "objc"
            "objcpp"
            "cuda"
            "proto"
          ];
          root_markers = [
            ".clangd"
            ".clang-tidy"
            ".clang-format"
            "compile_commands.json"
            "compile_flags.txt"
            "configure.ac"
            ".git"
          ];
        };
      };

      # Lua. The runtime-file library is what makes `vim.*` resolve when editing
      # this config's own lua, which is the job neodev used to do.
      lua_ls = {
        enable = true;
        config.settings.Lua = {
          runtime.version = "LuaJIT";
          diagnostics.globals = [ "vim" ];
          workspace = {
            checkThirdParty = false;
            library.__raw = ''vim.api.nvim_get_runtime_file("", true)'';
          };
          format.defaultConfig.align_continuous_assign_statement = "false";
          telemetry.enable = false;
          hint.enable = true;
        };
      };

      # Nix.
      #
      # In practice conform owns nix formatting (plugins/format.nix lists nixfmt
      # for the `nix` filetype and so never falls back to the LSP). This is kept
      # so that vim.lsp.buf.format() still does the right thing on its own.
      nixd = {
        enable = true;
        config.settings.nixd.formatting.command = [ "nixfmt" ];
      };

      just.enable = true;

      # Python: basedpyright for types, ruff for lint/format.
      basedpyright = {
        enable = true;
        config.settings.basedpyright.analysis = {
          typeCheckingMode = "basic";
          autoSearchPaths = true;
          useLibraryCodeForTypes = true;
        };
      };

      ruff = {
        enable = true;
        # Both servers attach to python buffers and both answer hover. Ruff's
        # answer is the less useful one, so it stands down and K always comes
        # from basedpyright.
        config.on_attach.__raw = ''
          function(client, _)
            client.server_capabilities.hoverProvider = false
          end
        '';
      };

      # TypeScript.
      #
      # NOTE: `javascript` is deliberately absent, matching the lua config --
      # add it here if you want ts_ls on plain .js too. (The lua config also
      # listed `typescript.tsx`, which is not a real neovim filetype and never
      # matched; `typescriptreact` is the one that does.)
      #
      # Formatting is declined so prettier/eslint can own it; plugins/format.nix
      # already refuses LSP formatting for these filetypes on save.
      ts_ls = {
        enable = true;
        config = {
          filetypes = [
            "typescript"
            "typescriptreact"
          ];
          on_attach.__raw = ''
            function(client, _)
              client.server_capabilities.documentFormattingProvider = false
            end
          '';
        };
      };

      zls = {
        enable = true;
        config.root_markers = [
          "zls.json"
          "build.zig"
          ".git"
        ];
      };

      # Devicetree. `single_file_support` from the lua config is dropped: it was
      # an nvim-lspconfig concept, and vim.lsp.config already starts a server
      # with a nil root when no marker is found.
      dts_lsp = {
        enable = true;
        config = {
          cmd = [ "dts-lsp" ];
          filetypes = [
            "dts"
            "dtsi"
            "dtso"
          ];
          root_markers = [
            "west.yml"
            "zephyr"
            ".git"
          ];
        };
      };

      # Prose: grammar and style in comments and markdown.
      harper_ls.enable = true;
    };

    # Registered on LspAttach, so they are buffer-local to buffers with a server.
    #
    # Deliberately short: nvim >= 0.11 already ships grr (references), gri
    # (implementation), grt (type definition), grn (rename), gra (code action),
    # gO (document symbols) and K (hover, set on attach). Mapped here are the two
    # it has no equivalent for, plus g. -- a nearer-to-hand alias for gra, which
    # is the one default worth reaching for often.
    #
    # Note gd is NOT an nvim default -- unmapped it stays vim's built-in "goto
    # local declaration", which searches backwards in the file and lands on the
    # import. Do not add a bare `gr`: it would shadow every gr* default above
    # behind 'timeoutlen'.
    lsp.keymaps = [
      {
        mode = "n";
        key = "gd";
        action = "<cmd>Telescope lsp_definitions<cr>";
        options.desc = "[G]oto [D]efinition";
      }
      {
        mode = "n";
        key = "<leader>ws";
        action = "<cmd>Telescope lsp_workspace_symbols<cr>";
        options.desc = "[W]orkspace [S]ymbols";
      }
      {
        mode = "n";
        key = "g.";
        action.__raw = "vim.lsp.buf.code_action";
        options.desc = "Code action (alias for gra)";
      }
    ];
  };
}
