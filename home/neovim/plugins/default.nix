# One file per plugin (or per tightly-coupled group). Add the file, add it here.
{ ... }:
{
  imports = [
    ./telescope.nix
    ./treesitter.nix
    ./format.nix
    ./completion.nix
    ./copilot.nix
    ./codecompanion.nix
    ./todo-comments.nix
    ./git.nix
    ./minimap.nix
    ./textobjects.nix
    ./harpoon.nix
    ./oil.nix
    ./themes.nix
    ./transparent.nix
    ./ui.nix
    ./which-key.nix
  ];
}
