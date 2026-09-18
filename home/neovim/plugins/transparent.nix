# transparent.nvim -- clears background highlights so the terminal shows through.
# Re-runs on every ColorScheme change, so it survives the theme picker.
{ ... }:
{
  programs.nixvim = {
    plugins.transparent.enable = true;

    # Without this the plugin reads its on/off state from a runtime cache file
    # (~/.local/share/nvim/transparent_cache), which is absent on a fresh
    # machine -- transparency would start OFF until you ran :TransparentEnable.
    # Declaring it here keeps it on by default. :TransparentToggle still works
    # for the current session; this global wins again at next startup.
    globals.transparent_enabled = true;
  };
}
