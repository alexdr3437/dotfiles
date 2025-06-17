
## Install

```zsh
git clone https://github.com/alexdr3437/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

If you're on a fresh NixOS build:

```zsh
sudo nixos-rebuild switch --flake .
```


To copy the dotfiles to their correct place:
```zsh
stow .
```

