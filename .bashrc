[ -f ~/.fzf.bash ] && source ~/.fzf.bash

echo "export FZF_DEFAULT_COMMAND='fd'" >> ~/.bashrc

. "$HOME/.cargo/env"
