# Colorscheme switcher: every theme installed, picked with `:Telescope colorscheme`,
# choice remembered across restarts.
#
# Deliberately does NOT use nixvim's `colorschemes.*` -- that emits a hardcoded
# colorscheme call at startup which would stomp the restored choice. The restore
# lua below owns the colorscheme instead.
{ nvimPkgs, ... }:
let
  # Used on first run, and as a fallback if the remembered theme is unavailable.
  defaultTheme = "tokyonight-night";

  # Written to ~/.local/share/nvim/colorscheme -- the nix store config is
  # read-only, so the choice has to persist somewhere writable.
  persistence = ''
    do
      local datadir = vim.fn.stdpath("data")
      local themefile = vim.fs.joinpath(datadir, "colorscheme")

      local function apply(name)
        return name ~= nil and pcall(vim.cmd.colorscheme, name)
      end

      local ok, saved = pcall(vim.fn.readfile, themefile)
      if not apply(ok and saved[1] or nil) then
        apply("${defaultTheme}")
      end

      -- Registered after the initial apply so startup does not rewrite the file.
      vim.api.nvim_create_autocmd("ColorScheme", {
        desc = "Remember the last colorscheme",
        callback = function(ev)
          vim.fn.mkdir(datadir, "p")
          local written, err = pcall(vim.fn.writefile, { ev.match }, themefile)
          if not written then
            vim.notify("Could not save colorscheme: " .. tostring(err), vim.log.levels.WARN)
          end
        end,
      })
    end
  '';
in
{
  programs.nixvim = {
    extraPlugins = with nvimPkgs.vimPlugins; [
      tokyonight-nvim
      catppuccin-nvim
      gruvbox-nvim
      kanagawa-nvim
      rose-pine
      nightfox-nvim
      everforest
      onedark-nvim
      oxocarbon-nvim
      melange-nvim
      nord-nvim
      dracula-nvim
      cyberdream-nvim
      vscode-nvim
      material-nvim
      monokai-pro-nvim
    ];

    # Merges into the telescope config from ./telescope.nix. Lives here because
    # it exists only for this picker.
    plugins.telescope.settings.pickers.colorscheme.enable_preview = true;

    extraConfigLua = persistence;

    keymaps = [
      {
        mode = "n";
        key = "<leader>th";
        action = "<cmd>Telescope colorscheme<cr>";
        options.desc = "[T]heme picker";
      }
    ];
  };
}
