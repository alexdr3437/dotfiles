{ pkgs, ... }:
{
  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "ls --color=auto -alFh";
      lz = "lazygit";
    };
    history.size = 500000;
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; } # Simple plugin installation
      ];
    };
    initContent = ''
      zmodload zsh/datetime

      preexec() {
        __cmd_start=$EPOCHREALTIME
        __cmd_start_fmt=$(strftime "%b %e, %l:%M:%S %p" $EPOCHSECONDS)

        print -P "%F{247}started $__cmd_start_fmt%f"
      }

      precmd() {
        [[ -z "$__cmd_start" ]] && return

        local end=$EPOCHREALTIME
        local dur=$(( end - __cmd_start ))
        printf -v dur "%.3f" "$dur"

        print -P "%F{247}took ''${dur}s%f"

        unset __cmd_start
      }

      PROMPT="%3~ ❯ "
    '';
  };

  home.packages = [ pkgs.bc ];
}
