# mini.map: a scaled-down render of the whole buffer, pinned right, with the
# git hunks / diagnostics / search hits of that buffer marked on it.
#
# Deliberately the split `mini.map` package, not the whole mini.nvim bundle --
# nothing else here uses mini.
{ ... }:
{
  programs.nixvim = {
    plugins.mini-map = {
      enable = true;

      settings = {
        window = {
          # Not focusable the normal way; <leader>gM (toggle_focus) is the way in,
          # so <C-l> and friends keep meaning "the window I actually want".
          focusable = false;
          side = "right";
          width = 10;
          # Opaque. Any winblend washes the git marks out against the buffer
          # showing through, which is the opposite of what they are for.
          winblend = 0;
          # A line that is several source lines tall gets a count, not just a mark.
          show_integration_count = true;
          zindex = 10;
        };

        symbols = {
          # Solid blocks at 3x2 resolution: every map cell covers 3 source lines
          # and 2 columns, which is what makes it read as an outline of the code
          # rather than a scrollbar.
          encode.__raw = ''require("mini.map").gen_encode_symbols.block("3x2")'';
          scroll_line = "█";
          scroll_view = "┃";
        };

        # `_M` exists from the top of init.lua but `_M.minimap` is only assigned
        # further down, in extraConfigLua -- so this has to be a closure, not a
        # direct reference, or it would capture nil at setup time.
        #
        # gen_integration.gitsigns() is deliberately NOT used here; see
        # _M.minimap.git_marks below for why.
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

        -- The map renders whatever buffer is current, and an outline of an oil
        -- listing or a help page is noise. A directory counts as "not a file"
        -- too: `nvim .` lands on one before oil takes over, and its name is a
        -- perfectly ordinary non-empty path with an empty buftype.
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

        -- Auto-open fires once. After that the map belongs to the user: a later
        -- BufWinEnter must not resurrect one they closed on purpose.
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

        -- Highlights ---------------------------------------------------------
        --
        -- The map is a picture, and the two things on it have opposite jobs: the
        -- encoded code outline is context and should recede, the git marks are
        -- the whole point and should not. mini.map paints both with `hl_group`
        -- over the glyphs, so this is all foreground colour.
        --
        -- Marks take their colour from whatever the current colorscheme already
        -- uses for git/diff, so this survives <leader>th, and are bolded to pull
        -- them forward of the dimmed outline.
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
          -- Set without `default`, so these win over mini.map's own links
          -- (MiniMapNormal -> NormalFloat, which is as bright as the buffer).
          vim.api.nvim_set_hl(0, "MiniMapNormal", { link = "Comment" })

          -- Marks are signal, not content, so they get the cell's *background*
          -- and read as a solid bar the way zed's scrollbar does. Tinting the
          -- glyphs instead is not enough: gutter colours are picked to be
          -- unobtrusive in a one-column gutter, and several themes put them a
          -- shade away from Comment -- tokyonight's change is #6183bb against a
          -- #565f89 outline, which is invisible at this size.
          -- Glyph colour on top of a mark bar. transparent.nvim clears Normal's
          -- background, so there is often nothing to read here and the bar needs
          -- a sane contrasting colour of its own.
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

        -- Git marks ----------------------------------------------------------
        --
        -- mini.map's own gitsigns integration calls gitsigns.get_hunks(), which
        -- reports *unstaged* hunks only -- stage a change and it drops off the
        -- map while staying in the sign column. gitsigns has no public way to
        -- ask for staged hunks (nav_hunk's `target` is the only thing that
        -- takes them, and it is not exposed here).
        --
        -- So read the signs gitsigns actually placed. Both namespaces are
        -- scanned, staged and unstaged, which makes the map agree with the
        -- gutter by construction and needs nothing but public API.
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
                  -- Order matters: "changedelete" holds both words, "topdelete"
                  -- holds "delete", and untracked is new code, so it reads as an add.
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
        # VimEnter covers `nvim file`; BufWinEnter covers starting in a directory
        # (oil) or on the dashboard and opening a file after.
        event = [
          "VimEnter"
          "BufWinEnter"
        ];
        group = "minimap";
        desc = "Open mini.map on the first real file buffer";
        callback.__raw = "function() _M.minimap.auto_open() end";
      }
      {
        # A colorscheme change wipes every highlight, and themes.nix restores a
        # saved one at startup, so both events have to re-apply these.
        event = [
          "VimEnter"
          "ColorScheme"
        ];
        group = "minimap";
        desc = "Dim the mini.map outline, brighten its git marks";
        callback.__raw = "function() _M.minimap.set_highlights() end";
      }
      {
        # gen_integration.gitsigns() installs this itself; since git_marks
        # replaces it, the refresh has to be wired up by hand. Without it the
        # map does not repaint when gitsigns attaches or a hunk changes.
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
