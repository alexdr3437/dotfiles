# nvim-cmp + LuaSnip. `autoEnableSources` enables the source plugins from settings.sources.
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

        # noinsert: nothing enters the buffer until confirmed
        completion.completeopt = "menu,menuone,noinsert";

        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<Down>" = "cmp.mapping.select_next_item()";
          "<Up>" = "cmp.mapping.select_prev_item()";

          "<C-b>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";

          "<C-Space>" = "cmp.mapping.complete({})";
          "<C-e>" = "cmp.mapping.close()";

          # Accept: a visible copilot suggestion first (the menu is closed then), else cmp.
          # pcall, so copilot.nix stays optional.
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

    # cmp's capabilities for every server (`*`), merged onto neovim's defaults; nixvim
    # only wires this up for the legacy `plugins.lsp`
    lsp.servers."*".config.capabilities.__raw = ''
      vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require("cmp_nvim_lsp").default_capabilities()
      )
    '';
  };
}
