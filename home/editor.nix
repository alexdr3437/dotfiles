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
    userSettings = {
      theme = {
        mode = "system";
        dark = "Ayu Dark";
        light = "Ayu Mirage";
      };
      preview_tabs = {
        enabled = true;
        enable_preview_from_file_finder = true;
      };
      hour_format = "hour24";
      vim_mode = true;
    };
  };
}
