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
          description = "Rust: rustup only, toolchain from rust-toolchain.toml";
        };
        zig = {
          path = ./zig;
          description = "Zig: zig and zls";
        };
        python = {
          path = ./python;
          description = "Python: uv only, Python and packages from uv";
        };
      };
    };
}
