# Return a list of all templates

{
  description = "A collection of flake templates";

  outputs =
    { self }:
    {
      templates = {
        rust = {
          path = ./rust;
          description = "Rust template, using Naersk";
        };
      };
    };
}
