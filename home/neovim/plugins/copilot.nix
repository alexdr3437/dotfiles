# copilot.lua: inline ghost-text suggestions.
#
# Needs a one-off `:Copilot auth` per machine -- the token lands in
# ~/.config/github-copilot, outside the nix store. `node` comes in through the
# module's own declared dependencies, so it does not need listing here.
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
        # completion.nix owns <C-y> and accepts suggestions itself.
        #
        # next/prev/dismiss keep their defaults: <M-]>, <M-[>, <C-]>.
        accept = false;
      };
    };
  };
}
