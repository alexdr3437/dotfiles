{ ... }:
{
  programs.nixvim = {
    plugins.telescope = {
      enable = true;

      # The <leader>p/<leader>s pickers all pass no_ignore + hidden, so without
      # these they would happily search .git/ and node_modules/.
      settings.defaults.file_ignore_patterns = [
        "%.*build/"
        "%.*git/"
        "%.*cache/"
        "%.*vscode/"
        "%.*idea/"
        "%.*DS_Store"
        "%.*node_modules/"
      ];

      # Plain builtin pickers, no cwd juggling needed.
      keymaps = {
        "<leader>ph" = {
          action = "help_tags";
          options.desc = "Search [H]elp";
        };
        "<leader>pk" = {
          action = "keymaps";
          options.desc = "Search [K]eymaps";
        };
        "<leader>pD" = {
          action = "diagnostics";
          options.desc = "[P]roject [D]iagnostics";
        };
        "<leader>pr" = {
          action = "resume";
          options.desc = "[P]roject [R]esume";
        };
        "<leader>p." = {
          action = "oldfiles";
          options.desc = "[P]roject recent files";
        };
        "<leader>pb" = {
          action = "buffers";
          options.desc = "[P]roject [B]uffers";
        };
      };
    };

    # Helpers behind the cwd-sensitive pickers. Kept on nixvim's `_M` table
    # rather than globals so nothing leaks into the global namespace.
    extraConfigLua = ''
      _M.telescope = (function()
        local M = {}

        -- The cwd nvim was launched from, captured once at startup.
        local launch_cwd = vim.uv.cwd()

        local function get_parent_dir(path)
          if path == "" or path == "/" or path == launch_cwd then
            return nil
          end
          return path:match("^(.*)/[^/]+$")
        end

        -- Walk up from the current file until a directory named `target_dir`
        -- turns up; fall back to the process cwd.
        local function find_dir(target_dir)
          local function dir_exists(path)
            local stat = vim.uv.fs_stat(path)
            return stat and stat.type == "directory" or false
          end

          local cwd = vim.fn.expand("%:p:h")
          local prefix = "oil://"
          if cwd:sub(1, #prefix) == prefix then
            cwd = cwd:sub(#prefix + 1)
          end

          while cwd do
            local target_path = cwd .. "/" .. target_dir
            if dir_exists(target_path) then
              return target_path
            end
            cwd = get_parent_dir(cwd)
          end
          return vim.uv.cwd()
        end

        -- Scope helpers.
        --
        -- Project pickers honour .gitignore; session pickers deliberately do
        -- not, so they can reach build output, vendored deps and the like.
        --
        -- find_files reads `no_ignore`, but live_grep/grep_string do NOT --
        -- they only ever look at `hidden` and `additional_args` -- so ripgrep
        -- has to be handed the flag directly.
        local function find_opts(dir, all_files)
          return {
            cwd = dir,
            hidden = true,
            no_ignore = all_files or nil,
          }
        end

        local function grep_opts(dir, all_files)
          return {
            cwd = dir,
            hidden = true,
            additional_args = all_files and { "--no-ignore" } or nil,
          }
        end

        local function src_dir()
          return find_dir("src")
        end

        local function src_parent()
          return get_parent_dir(find_dir("src"))
        end

        -- Project scope: relative to the nearest `src` directory, .gitignore respected.
        function M.project_local_files()
          require("telescope.builtin").find_files(find_opts(src_dir(), false))
        end

        function M.project_files()
          require("telescope.builtin").find_files(find_opts(src_parent(), false))
        end

        function M.project_grep()
          require("telescope.builtin").live_grep(grep_opts(src_parent(), false))
        end

        function M.project_word()
          require("telescope.builtin").grep_string(grep_opts(src_parent(), false))
        end

        -- Session scope: relative to where nvim was opened, ignore files included.
        function M.session_files()
          require("telescope.builtin").find_files(find_opts(launch_cwd, true))
        end

        function M.session_grep()
          require("telescope.builtin").live_grep(grep_opts(launch_cwd, true))
        end

        function M.session_word()
          require("telescope.builtin").grep_string(grep_opts(launch_cwd, true))
        end
        -- Exposed so other modules can reuse the same scope resolution.
        function M.project_dir()
          return src_parent()
        end

        function M.session_dir()
          return launch_cwd
        end

        function M.buffer_fuzzy_find()
          require("telescope.builtin").current_buffer_fuzzy_find(
            require("telescope.themes").get_dropdown({
              winblend = 10,
              previewer = false,
            })
          )
        end

        function M.grep_open_files()
          require("telescope.builtin").live_grep({
            grep_open_files = true,
            prompt_title = "Live Grep in Open Files",
          })
        end

        function M.dotfiles()
          require("telescope.builtin").find_files({ cwd = vim.fn.expand("~/.dotfiles") })
        end

        return M
      end)()
    '';

    keymaps = [
      # Project scope (<leader>p...)
      {
        mode = "n";
        key = "<leader>pp";
        action.__raw = "function() _M.telescope.project_local_files() end";
        options.desc = "[P]roject files under src";
      }
      {
        mode = "n";
        key = "<leader>pf";
        action.__raw = "function() _M.telescope.project_files() end";
        options.desc = "[P]roject [F]iles";
      }
      {
        mode = "n";
        key = "<leader>pg";
        action.__raw = "function() _M.telescope.project_grep() end";
        options.desc = "[P]roject [G]rep";
      }
      {
        mode = "n";
        key = "<leader>pw";
        action.__raw = "function() _M.telescope.project_word() end";
        options.desc = "[P]roject [W]ord";
      }

      # Session scope (<leader>s...)
      {
        mode = "n";
        key = "<leader>sf";
        action.__raw = "function() _M.telescope.session_files() end";
        options.desc = "[S]ession [F]iles";
      }
      {
        mode = "n";
        key = "<leader>sg";
        action.__raw = "function() _M.telescope.session_grep() end";
        options.desc = "[S]ession [G]rep";
      }
      {
        mode = "n";
        key = "<leader>sw";
        action.__raw = "function() _M.telescope.session_word() end";
        options.desc = "[S]ession [W]ord";
      }

      # Odds and ends
      {
        mode = "n";
        key = "<leader>/";
        action.__raw = "function() _M.telescope.buffer_fuzzy_find() end";
        options.desc = "[/] Fuzzily search in current buffer";
      }
      {
        mode = "n";
        key = "<leader>po";
        action.__raw = "function() _M.telescope.grep_open_files() end";
        options.desc = "Live grep in [O]pen files";
      }
      {
        mode = "n";
        key = "<leader>pn";
        action.__raw = "function() _M.telescope.dotfiles() end";
        options.desc = "Search [N]ix dotfiles";
      }
    ];
  };
}
