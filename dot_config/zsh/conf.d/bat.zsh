command -v bat >/dev/null 2>&1 || return

zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat -p --color=always $realpath'
alias cat="bat --paging=never"
