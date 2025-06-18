
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

setopt autocd extendedglob nomatch notify
unsetopt beep
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/alex/.zshrc'

autoload -Uz compinit
compinit

_comp_options+=(globdots) # complete hidden files
source ~/.config/zsh/completion.zsh

# enable ctrl-t, ctrl-r and alt-c fzf binds
if [ -n "${commands[fzf-share]}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

source ~/.config/zsh/prompt.zsh

eval "$(zoxide init zsh)"
