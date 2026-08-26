[[ -d ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote ]] || return

# Фаза 1 из 2: выполняется ДО compinit. Поднимает сам antidote и загружает
# .zsh_plugins.txt — там только плагины завершений с kind:fpath, которым нужно
# попасть в fpath раньше, чем compinit его прочитает.
# Всё остальное грузит antidote-post.zsh, уже после compinit.
#
# HOMEBREW_PREFIX экспортирует `brew shellenv` из .zprofile. Fallback нужен для
# не-login шеллов, которые .zprofile не читают; на Intel-маке это /usr/local.
# Проверяем каталог, а не `command -v antidote`: antidote — не бинарник в PATH,
# а автозагружаемая zsh-функция, которой до autoload ниже ещё не существует.

typeset brew_prefix=${HOMEBREW_PREFIX:-/opt/homebrew}
typeset zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins

fpath=($brew_prefix/opt/antidote/share/antidote/functions $fpath)
fpath+=($brew_prefix/share/zsh/site-functions)
autoload -Uz antidote

[[ -f ${zsh_plugins}.txt ]] || touch ${zsh_plugins}.txt
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  antidote bundle <${zsh_plugins}.txt >|${zsh_plugins}.zsh
fi
source ${zsh_plugins}.zsh

unset brew_prefix zsh_plugins
