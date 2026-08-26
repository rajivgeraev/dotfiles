(( $+functions[antidote] )) || return

# Фаза 2 из 2: выполняется ПОСЛЕ compinit. Загружает .zsh_plugins_post.txt —
# всё, что должно увидеть уже готовую систему завершений: прежде всего fzf-tab,
# а следом плагины, оборачивающие виджеты zle.
#
# Guard проверяет функцию antidote, а не каталог: этот файл имеет смысл ровно
# тогда, когда фаза 1 отработала успешно.

typeset zsh_plugins_post=${ZDOTDIR:-$HOME}/.zsh_plugins_post

[[ -f ${zsh_plugins_post}.txt ]] || touch ${zsh_plugins_post}.txt
if [[ ! ${zsh_plugins_post}.zsh -nt ${zsh_plugins_post}.txt ]]; then
  antidote bundle <${zsh_plugins_post}.txt >|${zsh_plugins_post}.zsh
fi
source ${zsh_plugins_post}.zsh

unset zsh_plugins_post
