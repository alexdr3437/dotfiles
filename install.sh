#!/bin/sh
# this script copies all the files to where they belong and installs any necessary dependencies

pwd=$(pwd)

sudo apt install git compton i3blocks stow tmux zsh cmake

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
cd $pwd
stow .

# betterlockscreen
wget https://raw.githubusercontent.com/betterlockscreen/betterlockscreen/main/install.sh -O - -q | bash -s user

# i3lock-color
sudo apt install autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

cd 
git clone https://github.com/Raymo111/i3lock-color.git
cd i3lock-color
./install-i3lock-color.sh

cd $pwd

