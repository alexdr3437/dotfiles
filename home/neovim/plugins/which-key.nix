# which-key: shows what can follow a prefix. Only the leader group names need declaring.
{ ... }:
{
  programs.nixvim.plugins.which-key = {
    enable = true;

    # `__unkeyed` is the lhs the group describes
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
      # mini.surround's bare `s`
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
