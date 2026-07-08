# Return a list of all templates

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
