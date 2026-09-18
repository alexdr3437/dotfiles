# nvim-cmp + LuaSnip: the completion menu, its sources, and its keymaps.
#
# Source plugins are not listed anywhere: `autoEnableSources` (on by default)
# reads settings.sources and enables cmp-nvim-lsp / cmp_luasnip / cmp-path for
# us, so the source list below is the single place a source is declared.
{ ... }:
{
  programs.nixvim = {
    plugins.luasnip.enable = true;

    plugins.cmp = {
      enable = true;

      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
        ];

        snippet.expand = ''
          function(args)
            require("luasnip").lsp_expand(args.body)
          end
        '';

        # noinsert: show the menu and preselect, but do not put anything in the
        # buffer until it is confirmed.
        completion.completeopt = "menu,menuone,noinsert";

        # The lua config built these with `cmp.mapping.preset.insert`, then
        # overrode every key the preset defines except <Down>/<Up> -- so the
        # preset is dropped here and those two are spelled out instead. Same
        # result, and the whole mapping table stays readable as nix.
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<Down>" = "cmp.mapping.select_next_item()";
          "<Up>" = "cmp.mapping.select_prev_item()";

          "<C-b>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";

          "<C-Space>" = "cmp.mapping.complete({})";
          "<C-e>" = "cmp.mapping.close()";

          # Accept. The lua config bound <C-y> twice -- once here as cmp's
          # confirm, and once as copilot's `suggestion.keymap.accept` -- which is
          # a straight collision, whichever plugin set its keymap last winning.
          #
          # Arbitrated here instead: copilot.nix turns its own keymap off and
          # leaves <C-y> to cmp, and this decides what the key means. Copilot
          # goes first because `hide_during_completion` (see copilot.nix) hides
          # its ghost text whenever the cmp menu is up -- so if a suggestion is
          # visible at all, the menu is closed and there is nothing to confirm.
          #
          # pcall-guarded rather than assumed, so this file still works if
          # copilot.nix is not in the imports.
          "<C-y>" = ''
            cmp.mapping(function(fallback)
              local ok, suggestion = pcall(require, "copilot.suggestion")
              if ok and suggestion.is_visible() then
                suggestion.accept()
              elseif cmp.visible() then
                cmp.confirm({ select = true })
              else
                fallback()
              end
            end, { "i", "s" })
          '';

          # Move to the right / left of each snippet expansion point.
          "<C-l>" = ''
            cmp.mapping(function()
              local luasnip = require("luasnip")
              if luasnip.expand_or_locally_jumpable() then
                luasnip.expand_or_jump()
              end
            end, { "i", "s" })
          '';
          "<C-h>" = ''
            cmp.mapping(function()
              local luasnip = require("luasnip")
              if luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
              end
            end, { "i", "s" })
          '';
        };
      };
    };

    # Tell the language servers what cmp can render.
    #
    # nixvim does this automatically, but only for `plugins.lsp` -- the legacy
    # LSP module. lsp.nix uses the newer `lsp.servers` module, which that wiring
    # never reaches, so it is done by hand here against `*`, the pseudo-server
    # whose config every real server inherits.
    #
    # cmp_nvim_lsp.default_capabilities() returns only the completion subtree,
    # not a complete capabilities table, so it has to be merged onto neovim's
    # defaults rather than assigned over them.
    lsp.servers."*".config.capabilities.__raw = ''
      vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require("cmp_nvim_lsp").default_capabilities()
      )
    '';
  };
}
