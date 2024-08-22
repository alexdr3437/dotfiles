#!/bin/zsh
# copies the config files to the correct location

cp .zshrc ~/.zshrc
source ~/.zshrc

cp -r nvim ~/.config/
cp -r tmux ~/.config/
cp -r alacritty ~/.config/
cp -r i3 ~/.config/
cp -r i3blocks ~/.config/

