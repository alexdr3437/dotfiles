#!/bin/zsh
# this script copies all the files to where they belong and installs any necessary dependencies

sudo apt install compton i3blocks

git submodule update --init --recursive --remote

cp -r nvim ~/.config/
cp -r tmux ~/.config/
cp -r alacritty ~/.config/
cp -r i3 ~/.config/
cp -r i3blocks ~/.config/

# betterlockscreen
wget https://raw.githubusercontent.com/betterlockscreen/betterlockscreen/main/install.sh -O - -q | bash -s user

# i3lock-color
sudo apt install autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

cd ..
git clone https://github.com/Raymo111/i3lock-color.git
cd i3lock-color
./install-i3lock-color.sh
