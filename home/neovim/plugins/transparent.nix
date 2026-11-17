# transparent.nvim -- clears background highlights so the terminal shows through.
# Re-runs on every ColorScheme change, so it survives the theme picker.
{ ... }:
{
  programs.nixvim = {
    plugins.transparent.enable = true;

    # on by default; otherwise the state comes from a cache file a fresh machine lacks
    globals.transparent_enabled = true;
  };
}
