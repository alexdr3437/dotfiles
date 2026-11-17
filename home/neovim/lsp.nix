# Language servers, plus the LSP keymaps nvim lacks. Each `config` is merged over
# nvim-lspconfig's defaults. Binaries come from the project dev shell (`package = null`);
# capabilities are set in plugins/completion.nix.
{ ... }:
{
  programs.nixvim = {
    plugins.lspconfig.enable = true;

    lsp.servers = {
      # Rust. checkOnSave off: cargo check on every write is expensive in a big workspace.
      rust_analyzer = {
        package = null;
        enable = true;
        config = {
          settings."rust-analyzer" = {
            cargo.allFeatures = false;
            checkOnSave = false;
            procMacro.enable = true;
            diagnostics.disabled = [
              "inactive-code"
              "inactive_code"
            ];
          };
          flags.debounce_text_changes = 150;
        };
      };

      # C / C++. NOTE: --tweaks takes clangd tweak names, so the two flags below are likely ignored.
      clangd = {
        package = null;
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

      # Lua. The runtime-file library makes `vim.*` resolve in this config's own lua.
      lua_ls = {
        package = null;
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

      # Nix. conform formats on save; the formatter here is for vim.lsp.buf.format().
      nixd = {
        package = null;
        enable = true;
        config.settings.nixd.formatting.command = [ "nixfmt" ];
      };

      just = {
        enable = true;
        package = null;
      };

      # Python: basedpyright for types, ruff for lint/format.
      basedpyright = {
        package = null;
        enable = true;
        config.settings.basedpyright.analysis = {
          typeCheckingMode = "basic";
          autoSearchPaths = true;
          useLibraryCodeForTypes = true;
        };
      };

      ruff = {
        package = null;
        enable = true;
        # hover comes from basedpyright, not ruff
        config.on_attach.__raw = ''
          function(client, _)
            client.server_capabilities.hoverProvider = false
          end
        '';
      };

      # TypeScript (not plain javascript). Formatting is left to prettier/eslint.
      ts_ls = {
        package = null;
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

      # OCaml.
      ocamllsp = {
        package = null;
        enable = true;
      };

      zls = {
        package = null;
        enable = true;
        config.root_markers = [
          "zls.json"
          "build.zig"
          ".git"
        ];
      };

      # Devicetree.
      dts_lsp = {
        package = null;
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
    };

    # Buffer-local, on LspAttach: what nvim's defaults (grn, gra, gri, grt, gO, K) lack, g. as
    # an alias for gra, and grr through telescope. No bare `gr`: it would shadow the gr* defaults.
    lsp.keymaps = [
      {
        mode = "n";
        key = "gd";
        action = "<cmd>Telescope lsp_definitions<cr>";
        options.desc = "[G]oto [D]efinition";
      }
      {
        mode = "n";
        key = "grr";
        action = "<cmd>Telescope lsp_references<cr>";
        options.desc = "[G]oto [R]eferences";
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
