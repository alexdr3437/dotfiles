# todo-comments: highlights TODO / FIX / HACK / WARN / PERF / NOTE / TEST in
# comments, and lists them project-wide.
{ ... }:
{
  programs.nixvim.plugins.todo-comments = {
    enable = true;

    # no signs: gitsigns owns the one-cell gutter
    settings.signs = false;

    # joins the <leader>p pickers in telescope.nix
    keymaps.todoTelescope = {
      key = "<leader>pt";
      options.desc = "[P]roject [T]odos";
    };
  };
}
