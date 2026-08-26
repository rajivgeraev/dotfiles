command -v eza >/dev/null 2>&1 || return

alias ls="eza --git --group-directories-first"
alias ll="eza -al --git --group-directories-first"
