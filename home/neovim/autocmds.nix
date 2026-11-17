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
        callback.__raw = "function() vim.hl.hl_op() end";
      }
    ];
  };
}
