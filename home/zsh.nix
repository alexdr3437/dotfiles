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

    completionInit = ''
      bindkey '^Y' autosuggest-accept
      bindkey '^[[C' forward-char
    '';

    setOptions = [
      "EXTENDED_HISTORY"
      "RM_STAR_WAIT"
      "PROMPT_SUBST"
    ];

    shellAliases = {
      ls = "ls --color=auto -alFh";
      lz = "lazygit";
      ndev = "nix develop -c zsh";
    };
    history.size = 500000;
    initContent = ''
      zmodload zsh/datetime

      ntmp() {
        local dir="$HOME/.dotfiles/templates/$1"
        if [[ -z "$1" || ! -d "$dir" ]]; then
          local -a tmpls
          tmpls=("$HOME"/.dotfiles/templates/*(/:t))
          echo "usage: ntmp <template>  (available: $tmpls)" >&2
          return 1
        fi
        nix develop --no-write-lock-file "$dir" -c zsh
      }

      preexec() {
        __cmd_start=$EPOCHREALTIME
      }

      precmd() {
        [[ -z "$__cmd_start" ]] && return

        local end=$EPOCHREALTIME
        local dur=$(( end - __cmd_start ))
        printf -v dur "%.3f" "$dur"

        if (( $(echo "$dur > 0.1" | bc -l) )); then
          print -P "%F{247}took ''${dur}s%f"
        fi

        unset __cmd_start
      }

      function prompt_path() {
        local path="''${PWD/#$HOME/~}"
        local parts=("''${(s:/:)path}")

        if (( ''${#parts} <= 4 )); then
          echo "$path"
        else
          echo "''${parts[1]}/.../''${parts[-3]}/''${parts[-2]}/''${parts[-1]}"
        fi
      }

      PROMPT='$(prompt_path) ❯ '
    '';
  };

  home.packages = [ pkgs.bc ];
}
