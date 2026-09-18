# harpoon2. The plugin module owns its own keymaps; base keymaps live outside plugins/.
{ lib, ... }:
{
  programs.nixvim = {
    plugins.harpoon = {
      enable = true;
      enableTelescope = true;
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>a";
        action.__raw = "function() require('harpoon'):list():add() end";
        options.desc = "H[a]rpoon add file";
      }
      {
        mode = "n";
        key = "<leader>he";
        action.__raw = ''
          function()
            local harpoon = require('harpoon')
            harpoon.ui:toggle_quick_menu(harpoon:list())
          end
        '';
        options.desc = "[H]arpoon quick m[e]nu";
      }
    ]
    ++ map (n: {
      mode = "n";
      key = "<leader>h${toString n}";
      action.__raw = "function() require('harpoon'):list():select(${toString n}) end";
      options.desc = "[H]arpoon file ${toString n}";
    }) (lib.range 1 8);
  };
}
