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

      # Load-bearing, not decoration: it is what keeps ghost text and the cmp
      # menu from ever being on screen together, which is what lets the <C-y>
      # mapping in completion.nix pick between them without guessing.
      hide_during_completion = true;

      keymap = {
        # The lua config asked for <C-y> here, which collided with nvim-cmp's
        # confirm on the same key. completion.nix now owns <C-y> and calls
        # `suggestion.accept()` itself, so copilot must not also map it.
        #
        # next/prev/dismiss keep their defaults: <M-]>, <M-[>, <C-]>.
        accept = false;
      };
    };
  };
}
