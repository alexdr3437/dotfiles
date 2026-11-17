# mini.map: a minimap pinned right, marking git hunks, diagnostics and search hits.
{ ... }:
{
  programs.nixvim = {
    plugins.mini-map = {
      enable = true;

      settings = {
        window = {
          # focus only through <leader>gM
          focusable = false;
          side = "right";
          width = 10;
          # opaque, so the git marks stay readable
          winblend = 0;
          # A line that is several source lines tall gets a count, not just a mark.
          show_integration_count = true;
          zindex = 10;
        };

        symbols = {
          # solid blocks: each cell covers 3 source lines and 2 columns
          encode.__raw = ''require("mini.map").gen_encode_symbols.block("3x2")'';
          scroll_line = "█";
          scroll_view = "┃";
        };

        # a closure: `_M.minimap` is only assigned later, in extraConfigLua
        integrations.__raw = ''
          {
            function() return _M.minimap.git_marks() end,
            require("mini.map").gen_integration.diagnostic(),
            require("mini.map").gen_integration.builtin_search(),
          }
        '';
      };
    };

    # mini.map never opens itself.
    extraConfigLua = ''
      _M.minimap = (function()
        local M = {}

        -- real files only: no oil listings, help pages or directories
        local function is_file_buffer()
          if vim.bo.buftype ~= "" then
            return false
          end
          local name = vim.api.nvim_buf_get_name(0)
          if name == "" or name:match("^%w+://") then
            return false
          end
          return vim.fn.isdirectory(name) == 0
        end

        -- auto-open fires once, so a map closed on purpose stays closed
        local opened = false

        function M.auto_open()
          if opened or not is_file_buffer() then
            return
          end
          opened = true
          require("mini.map").open()
        end

        function M.toggle()
          opened = true
          require("mini.map").toggle()
        end

        function M.toggle_focus()
          require("mini.map").toggle_focus()
        end

        -- Highlights: the outline recedes; git marks are solid bars in the colorscheme's
        -- git colours (gutter colours are too faint as glyph tints)
        local git_hl = {
          add = { name = "MiniMapGitAdd", from = { "GitSignsAdd", "Added", "DiffAdd" } },
          change = { name = "MiniMapGitChange", from = { "GitSignsChange", "Changed", "DiffChange" } },
          delete = { name = "MiniMapGitDelete", from = { "GitSignsDelete", "Removed", "DiffDelete" } },
        }

        -- First of `names` the colorscheme actually gives a foreground to.
        local function first_fg(names)
          for _, name in ipairs(names) do
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
            if ok and hl and hl.fg then
              return hl.fg
            end
          end
        end

        function M.set_highlights()
          -- no `default`, so these win over mini.map's own links
          vim.api.nvim_set_hl(0, "MiniMapNormal", { link = "Comment" })

          -- glyph colour on a mark bar (transparent.nvim clears Normal's background)
          local ok, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
          local base = (ok and normal.bg) or (vim.o.background == "dark" and 0x101010 or 0xf0f0f0)

          for _, spec in pairs(git_hl) do
            local color = first_fg(spec.from)
            if color then
              vim.api.nvim_set_hl(0, spec.name, { bg = color, fg = base, bold = true })
            else
              vim.api.nvim_set_hl(0, spec.name, { link = spec.from[1] })
            end
          end
        end

        -- Git marks: read the signs gitsigns placed, staged and unstaged; mini.map's own
        -- integration only sees unstaged hunks
        function M.git_marks()
          local buf = MiniMap.current.buf_data.source
          if not buf or not vim.api.nvim_buf_is_valid(buf) then
            return {}
          end

          local marks = {}
          for ns_name, ns in pairs(vim.api.nvim_get_namespaces()) do
            if ns_name:match("^gitsigns_signs") then
              local extmarks =
                vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
              for _, extmark in ipairs(extmarks) do
                local group = extmark[4] and extmark[4].sign_hl_group
                if group then
                  -- GitSigns[Staged]{Add,Change,Delete,Topdelete,Changedelete,Untracked}.
                  -- Order matters: the names contain each other. Untracked counts as an add.
                  local g = group:lower()
                  local kind = (g:find("untracked") and "add")
                    or (g:find("change") and "change")
                    or (g:find("delete") and "delete")
                    or (g:find("add") and "add")
                  if kind then
                    table.insert(marks, { line = extmark[2] + 1, hl_group = git_hl[kind].name })
                  end
                end
              end
            end
          end
          return marks
        end

        return M
      end)()
    '';

    autoGroups.minimap.clear = true;

    autoCmd = [
      {
        # VimEnter: `nvim file`; BufWinEnter: starting in a directory (oil)
        event = [
          "VimEnter"
          "BufWinEnter"
        ];
        group = "minimap";
        desc = "Open mini.map on the first real file buffer";
        callback.__raw = "function() _M.minimap.auto_open() end";
      }
      {
        # a colorscheme change wipes these highlights
        event = [
          "VimEnter"
          "ColorScheme"
        ];
        group = "minimap";
        desc = "Dim the mini.map outline, brighten its git marks";
        callback.__raw = "function() _M.minimap.set_highlights() end";
      }
      {
        # repaint when gitsigns attaches or a hunk changes
        event = [ "User" ];
        pattern = "GitSignsUpdate";
        group = "minimap";
        desc = "Repaint mini.map git marks on gitsigns update";
        callback.__raw = ''
          function()
            if package.loaded["mini.map"] then
              require("mini.map").refresh({}, { lines = false, scrollbar = false })
            end
          end
        '';
      }
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>gm";
        action.__raw = "function() _M.minimap.toggle() end";
        options.desc = "[G]it [M]ap toggle";
      }
      {
        mode = "n";
        key = "<leader>gM";
        action.__raw = "function() _M.minimap.toggle_focus() end";
        options.desc = "[G]it [M]ap focus";
      }
    ];
  };
}
