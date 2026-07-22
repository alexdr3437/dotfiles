{ ... }:
{
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
      "rust"
      "zig"
    ];
    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "super-f" = "terminal_panel::Toggle";
        };
      }
    ];
    userSettings = {
      theme = {
        mode = "system";
        dark = "Ayu Mirage";
        light = "Ayu Light";
      };
      preview_tabs = {
        enabled = true;
        enable_preview_from_file_finder = true;
      };
      hour_format = "hour24";
      vim_mode = true;
      vim = {
        toggle_relative_line_numbers = true;
      };
    };
  };
}
