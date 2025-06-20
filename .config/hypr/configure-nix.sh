#!/bin/sh
kitty -e sh -c '
	nvim ~/nixos/configuration.nix +/systemPackages +/] +normal\ O +normal\ i\ \ \ \ \  && sudo nixos-rebuild switch --flake ~/nixos
	if [ $? -ne 0 ] || ! sudo nixos-rebuild switch --flake "$HOME/nixos"; then
    echo
    echo "❌ something failed. press enter to close..."
    read
  fi
'
