command -v starship >/dev/null 2>&1 || return

export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
eval "$(starship init zsh)"
