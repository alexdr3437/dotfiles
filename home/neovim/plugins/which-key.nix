# which-key: after a prefix is typed, shows what can follow it.
#
# Every keymap in this config already carries a `desc`, which which-key picks up
# on its own. The one thing it cannot infer is what a *prefix* means, so the
# leader groups this config actually uses are named below.
{ ... }:
{
  programs.nixvim.plugins.which-key = {
    enable = true;

    # `__unkeyed` is the positional first element of the spec entry -- the lhs
    # the group describes.
    settings.spec = [
      {
        __unkeyed = "<leader>p";
        group = "project";
      }
      {
        __unkeyed = "<leader>s";
        group = "session";
      }
      {
        __unkeyed = "<leader>g";
        group = "git";
      }
      {
        __unkeyed = "<leader>h";
        group = "harpoon";
      }
      {
        __unkeyed = "<leader>t";
        group = "theme";
      }
      {
        __unkeyed = "<leader>c";
        group = "ai";
      }
      {
        __unkeyed = "<leader>cn";
        group = "new chat";
      }
      # Not a leader prefix: mini.surround owns bare `s` in normal and visual
      # mode, so which-key pops up here too.
      {
        __unkeyed = "s";
        mode = [
          "n"
          "x"
        ];
        group = "surround";
      }
    ];
  };
}
