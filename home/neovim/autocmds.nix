# Base autocommands.
{ ... }:
{
  programs.nixvim = {
    autoGroups.highlight-yank.clear = true;

    autoCmd = [
      {
        event = [ "TextYankPost" ];
        group = "highlight-yank";
        desc = "Highlight when yanking (copying) text";
        # vim.highlight.on_yank -> vim.hl.hl_op; same defaults (IncSearch, 150ms).
        callback.__raw = "function() vim.hl.hl_op() end";
      }
    ];
  };
}
