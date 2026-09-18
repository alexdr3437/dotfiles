# todo-comments: highlights TODO / FIX / HACK / WARN / PERF / NOTE / TEST in
# comments, and lists them project-wide.
{ ... }:
{
  programs.nixvim.plugins.todo-comments = {
    enable = true;

    # No sign column entries. The gutter is one cell wide and gitsigns already
    # owns it -- a todo sign would just push the git sign out of the way.
    # Highlighting the keyword in the comment itself is the useful half.
    settings.signs = false;

    # Joins the rest of the <leader>p pickers in telescope.nix. The module emits
    # this as `<cmd>TodoTelescope<cr>` and asserts telescope is enabled.
    keymaps.todoTelescope = {
      key = "<leader>pt";
      options.desc = "[P]roject [T]odos";
    };
  };
}
