#!/bin/sh
# this script copies all the files to where they belong and installs any necessary dependencies

pwd=$(pwd)

sudo apt install git stow tmux zsh cmake gettext htop

cd 
git clone https://github.com/neovim/neovim.git
cd neovim
make CMAKE_BUILD_TYPE=Release
sudo make install

cd $pwd

# set zsh as default shell
chsh -s $(which zsh)

# zsh config
git clone git@github.com:softmoth/zsh-vim-mode.git ~/.oh-my-zsh/custom/plugins/zsh-vim-mode
git clone git@github.com:zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone git@github.com:zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone git@github.com:zsh-users/zsh-completions.git ~/.oh-my-zsh/custom/plugins/zsh-completions

# install fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# install dotfiles
cd 
mv .zshrc .zshrc.bak 

cd $pwd
stow .
