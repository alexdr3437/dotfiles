# Git: inline signs, plus two pickers scoped like <leader>pf / <leader>pg.
{ ... }:
{
  programs.nixvim = {
    plugins.gitsigns = {
      enable = true;

      settings = {
        # Spelled out so the gutter and the mini.map marks agree on what each
        # kind of change looks like.
        signs = {
          add.text = "│";
          change.text = "│";
          delete.text = "_";
          topdelete.text = "‾";
          changedelete.text = "~";
          untracked.text = "┆";
        };

        # NOTE: `show_deleted` does NOT belong here. gitsigns marks it deprecated
        # in its config schema, so passing it through setup() prints
        # "show_deleted is now deprecated; ignoring" and drops it on the floor.
        # The runtime flag is still honoured, so <leader>gD flips it directly.
      };
    };

    extraConfigLua = ''
      _M.gitpick = (function()
        local M = {}

        local function git(dir, args)
          local cmd = { "git", "-C", dir }
          vim.list_extend(cmd, args)

          local ok, res = pcall(function()
            return vim.system(cmd, { text = true }):wait(10000)
          end)

          if not ok or res.code ~= 0 then
            return nil
          end
          return res.stdout or ""
        end

        -- Every added or modified line in the working tree, as {path, lnum, text}.
        -- Paths are relative to `dir` thanks to --relative, which also scopes the
        -- diff to that subtree -- matching how <leader>pf/<leader>pg are scoped.
        local function collect(dir)
          local entries = {}

          -- -U0 means no context lines, so every + line is a real change.
          -- Before the first commit there is no HEAD, so fall back to diffing
          -- against git's empty tree -- anything already staged still counts.
          local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
          local diff = git(dir, { "diff", "HEAD", "-U0", "--relative", "--no-color" })
            or git(dir, { "diff", EMPTY_TREE, "-U0", "--relative", "--no-color" })

          if diff then
            local path, lnum
            for line in vim.gsplit(diff, "\n", { plain = true }) do
              if line:match("^%+%+%+ ") then
                -- "+++ b/<path>", or "+++ /dev/null" for a deleted file.
                path = line:match("^%+%+%+ b/(.*)$")
                lnum = nil
              elseif line:match("^@@") then
                lnum = tonumber(line:match("^@@ %-%d+,?%d* %+(%d+)"))
              elseif path and lnum and line:sub(1, 1) == "+" then
                table.insert(entries, { path = path, lnum = lnum, text = line:sub(2) })
                lnum = lnum + 1
              end
              -- "-" lines are removals: nothing to jump to in the working tree.
            end
          end

          -- Untracked files are new in their entirety.
          local untracked = git(dir, { "ls-files", "--others", "--exclude-standard" })
          if untracked then
            for file in vim.gsplit(untracked, "\n", { plain = true }) do
              if file ~= "" then
                local abs = vim.fs.joinpath(dir, file)
                if vim.fn.getfsize(abs) <= 1024 * 1024 then
                  local ok, lines = pcall(vim.fn.readfile, abs)
                  if ok then
                    for i, text in ipairs(lines) do
                      table.insert(entries, { path = file, lnum = i, text = text })
                    end
                  end
                end
              end
            end
          end

          return entries
        end

        M.collect = collect

        -- Files git reports as changed. Telescope's own picker, so it keeps the
        -- diff preview and staging mappings.
        function M.changed_files(dir)
          require("telescope.builtin").git_status({ cwd = dir })
        end

        -- Fuzzy over the changed lines themselves.
        function M.changed_lines(dir)
          local entries = collect(dir)

          if #entries == 0 then
            vim.notify("No changed lines under " .. dir, vim.log.levels.INFO)
            return
          end

          local conf = require("telescope.config").values

          require("telescope.pickers")
            .new({}, {
              prompt_title = "Changed lines",
              finder = require("telescope.finders").new_table({
                results = entries,
                entry_maker = function(e)
                  local display = string.format("%s:%d: %s", e.path, e.lnum, e.text)
                  return {
                    value = e,
                    display = display,
                    ordinal = display,
                    filename = vim.fs.joinpath(dir, e.path),
                    lnum = e.lnum,
                    col = 1,
                  }
                end,
              }),
              sorter = conf.generic_sorter({}),
              previewer = conf.grep_previewer({}),
            })
            :find()
        end

        return M
      end)()

      -- The sticky whole-buffer diff overlay behind <leader>gD and <Esc>.
      --
      -- Owns its own on/off flag rather than reading gitsigns' config table:
      -- that table is internal, and nothing else in this config touches these
      -- three settings, so there is nothing for the flag to drift against.
      _M.gitdiff = (function()
        local M = {}

        local on = false

        -- preview_hunk_inline() is three effects, so the sticky version is three
        -- flags: show_deleted for removed lines, linehl for the full-line wash
        -- over added/changed ones, word_diff for the intra-line regions. The
        -- toggles only set flags; refresh() is what redraws.
        local function apply(value)
          local gs = require("gitsigns")
          gs.toggle_deleted(value)
          gs.toggle_linehl(value)
          gs.toggle_word_diff(value)
          gs.refresh()
          on = value
        end

        function M.toggle()
          apply(not on)
        end

        -- Only touches gitsigns when the overlay is actually up. <Esc> is pressed
        -- constantly, and an unconditional refresh() on every press would be
        -- flicker for nothing.
        function M.clear()
          if on then
            apply(false)
          end
        end

        return M
      end)()
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>gf";
        action.__raw = "function() _M.gitpick.changed_files(_M.telescope.project_dir()) end";
        options.desc = "[G]it changed [F]iles";
      }
      {
        mode = "n";
        key = "<leader>gl";
        action.__raw = "function() _M.gitpick.changed_lines(_M.telescope.project_dir()) end";
        options.desc = "[G]it changed [L]ines";
      }

      # Hunk navigation. Note [ = next and ] = previous, matching [d/]d and [q/]q.
      #
      # target = "all" is load-bearing. gitsigns defaults to "unstaged", so with
      # a staged working tree every one of these answers "No hunks" -- which is
      # wrong for this config, where <leader>gf/<leader>gl already diff against
      # HEAD and make no distinction between staged and not.
      #
      # gitsigns re-opens an already-open preview at the hunk it lands on, so
      # after <leader>gd these walk the diffs with the deleted lines still up.
      {
        mode = "n";
        key = "[c";
        action.__raw = ''function() require("gitsigns").nav_hunk("next", { target = "all" }) end'';
        options.desc = "Go to next git [C]hange";
      }
      {
        mode = "n";
        key = "]c";
        action.__raw = ''function() require("gitsigns").nav_hunk("prev", { target = "all" }) end'';
        options.desc = "Go to previous git [C]hange";
      }

      # Removed lines have nowhere to sit in the working tree, so they are hidden
      # until asked for. Two ways to ask, because they answer different questions.
      #
      # <leader>gd is zed's editor::ToggleSelectedDiffHunks: the hunk under the
      # cursor only, cleared again on CursorMoved/InsertEnter/BufLeave.
      {
        mode = "n";
        key = "<leader>gd";
        action.__raw = ''function() require("gitsigns").preview_hunk_inline() end'';
        options.desc = "[G]it [D]eleted lines (hunk)";
      }
      # <leader>gD is the sticky one: the same picture as <leader>gd but for every
      # hunk in the buffer, until toggled off -- by pressing it again, or by <Esc>
      # along with the search highlight (see keymaps.nix).
      {
        mode = "n";
        key = "<leader>gD";
        action.__raw = "function() _M.gitdiff.toggle() end";
        options.desc = "[G]it full [D]iff (buffer)";
      }
      {
        mode = "n";
        key = "<leader>gp";
        action.__raw = ''function() require("gitsigns").preview_hunk() end'';
        options.desc = "[G]it [P]review hunk";
      }

      # Staging and resetting. The visual variants take the selected range, which
      # is how you stage or reset part of a hunk.
      {
        mode = "n";
        key = "<leader>gs";
        action.__raw = ''function() require("gitsigns").stage_hunk() end'';
        options.desc = "[G]it [S]tage hunk";
      }
      {
        mode = "v";
        key = "<leader>gs";
        action.__raw = ''
          function()
            require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end
        '';
        options.desc = "[G]it [S]tage selection";
      }
      {
        mode = "n";
        key = "<leader>gr";
        action.__raw = ''function() require("gitsigns").reset_hunk() end'';
        options.desc = "[G]it [R]eset hunk";
      }
      {
        mode = "v";
        key = "<leader>gr";
        action.__raw = ''
          function()
            require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end
        '';
        options.desc = "[G]it [R]eset selection";
      }
      {
        mode = "n";
        key = "<leader>gS";
        action.__raw = ''function() require("gitsigns").stage_buffer() end'';
        options.desc = "[G]it [S]tage buffer";
      }
      {
        mode = "n";
        key = "<leader>gR";
        action.__raw = ''function() require("gitsigns").reset_buffer() end'';
        options.desc = "[G]it [R]eset buffer";
      }

      # Blame and diff.
      {
        mode = "n";
        key = "<leader>gb";
        action.__raw = ''function() require("gitsigns").blame_line() end'';
        options.desc = "[G]it [B]lame line";
      }
      {
        mode = "n";
        key = "<leader>gB";
        action.__raw = ''function() require("gitsigns").blame() end'';
        options.desc = "[G]it [B]lame buffer";
      }
      {
        mode = "n";
        key = "<leader>gv";
        action.__raw = ''function() require("gitsigns").diffthis() end'';
        options.desc = "[G]it diff [V]iew";
      }
    ];
  };
}
