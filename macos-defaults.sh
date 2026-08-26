#!/bin/zsh

# Настройки системы macOS. Запускается последним шагом bootstrap.sh, но
# самодостаточен — можно вызвать отдельно, чтобы применить только косметику:
#
#   ./macos-defaults.sh
#
# Все команды идемпотентны: повторный запуск ничего не ломает.

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${CYAN}${BOLD}==> 🍎 macOS Defaults${NC}\n"

# Finder: список вместо значков
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Finder: показывать path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: сортировать папки первыми
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Dock: горячий угол снизу-справа — Quick Note
defaults write com.apple.dock wvous-br-corner -int 14
defaults write com.apple.dock wvous-br-modifier -int 0

# Меню-бар часы: показывать день недели
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true

# Системный alert-звук: громкость 0 (тихо)
defaults write NSGlobalDomain com.apple.sound.beep.volume -float 0

# Перезапуск, чтобы изменения подхватились без релогина.
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo -e "${GREEN}${BOLD}  ok macOS defaults applied${NC}"
