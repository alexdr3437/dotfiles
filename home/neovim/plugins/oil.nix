# oil.nvim, plus the :Dirs picker that launches it.
#
# :Dirs lists the immediate subdirectories of its arguments and opens the
# chosen one in oil. With no arguments it reads the list from a .nvim/dirs.lua
# found by walking up from the current file.
{ ... }:
{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      settings.view_options.show_hidden = true;
    };

    extraConfigLua = ''
      _M.oil = (function()
        local M = {}

        function M.dirs(roots)
          local dirs = {}

          for _, root in ipairs(roots) do
            root = vim.fn.fnamemodify(vim.fn.expand(root), ":p")

            for name, kind in vim.fs.dir(root) do
              if kind == "directory" then
                table.insert(dirs, vim.fs.joinpath(root, name))
              end
            end
          end

          require("telescope.pickers")
            .new({}, {
              prompt_title = "Directories",
              finder = require("telescope.finders").new_table({
                results = dirs,
                entry_maker = function(path)
                  return {
                    value = path,
                    display = vim.fs.basename(path),
                    ordinal = vim.fs.basename(path),
                  }
                end,
              }),
              sorter = require("telescope.config").values.generic_sorter({}),
              attach_mappings = function(prompt_bufnr)
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")

                actions.select_default:replace(function()
                  local selection = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)

                  local path = selection.value

                  -- Prefer the src/ subdirectory when the pick has one.
                  local src = vim.fs.joinpath(path, "src")
                  local stat = vim.uv.fs_stat(src)
                  if stat and stat.type == "directory" then
                    path = src
                  end

                  vim.cmd("Oil " .. vim.fn.fnameescape(path))
                end)

                return true
              end,
            })
            :find()
        end

        -- Resolve the roots for a bare `:Dirs` from .nvim/dirs.lua, which is
        -- expected to return a list of directories relative to its project.
        function M.roots_from_project_file()
          local project_file = vim.fs.find(".nvim/dirs.lua", {
            upward = true,
            path = vim.fn.expand("%:p:h"),
          })[1]

          if not project_file then
            vim.notify("No .nvim/dirs.lua found and no directories supplied", vim.log.levels.ERROR)
            return nil
          end

          local project_root = vim.fs.dirname(vim.fs.dirname(project_file))
          local ok, configured_roots = pcall(dofile, project_file)

          if not ok or type(configured_roots) ~= "table" then
            vim.notify("Failed to load " .. project_file, vim.log.levels.ERROR)
            return nil
          end

          local roots = {}
          for _, dir in ipairs(configured_roots) do
            table.insert(roots, vim.fs.joinpath(project_root, dir))
          end
          return roots
        end

        return M
      end)()

      vim.api.nvim_create_user_command("Dirs", function(opts)
        local roots = opts.fargs

        if #roots == 0 then
          roots = _M.oil.roots_from_project_file()
          if not roots then
            return
          end
        end

        _M.oil.dirs(roots)
      end, {
        nargs = "*",
        complete = "dir",
        desc = "Pick a directory and open it in oil",
      })
    '';

    keymaps = [
      {
        mode = "n";
        key = "-";
        action = "<cmd>Oil<cr>";
        options.desc = "Open parent directory in oil";
      }
      {
        mode = "n";
        key = "<leader>pd";
        action = "<cmd>Dirs<cr>";
        options.desc = "[P]roject [D]irs";
      }
    ];
  };
}
