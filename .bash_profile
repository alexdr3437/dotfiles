# set format
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# set path
export PATH=/opt/homebrew/bin:$PATH
export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-16.0.2.jdk/Contents/Home"

#clear and print current date and time
tput reset
now=`date`
echo 'Current Time : ' $now 
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/alex/opt/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/alex/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/alex/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/alex/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PS1='@ %3~ %# '
