command -v zoxide >/dev/null 2>&1 || return

eval "$(zoxide init zsh --cmd cd)"
