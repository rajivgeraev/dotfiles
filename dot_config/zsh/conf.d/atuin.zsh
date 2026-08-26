command -v atuin >/dev/null 2>&1 || return

eval "$(atuin init zsh)"
# bindkey "^[[0;3A" atuin-search
