# The project templates: `nix flake init -t ~/.dotfiles#<name>` (the root flake exposes this
# list), or `ntmp <name>` (home/zsh.nix) for a dev shell from one.

{
  description = "A collection of flake templates";

  outputs =
    { self }:
    {
      templates = {
        rust = {
          path = ./rust;
          description = "Rust template";
        };
        zig = {
          path = ./zig;
          description = "Zig template";
        };
        python = {
          path = ./python;
          description = "Python template, using uv";
        };
      };
    };
}
