# copilot.lua: inline ghost-text suggestions. Needs a one-off `:Copilot auth` per machine.
{ ... }:
{
  programs.nixvim.plugins.copilot-lua = {
    enable = true;

    settings.suggestion = {
      enabled = true;

      # Suggest as you type rather than waiting for a key.
      auto_trigger = true;

      # Load-bearing for the <C-y> arbitration; see completion.nix.
      hide_during_completion = true;

      keymap = {
        # completion.nix owns <C-y>; next/prev/dismiss keep their defaults
        accept = false;
      };
    };
  };
}
