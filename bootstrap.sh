#!/bin/zsh

# Полная настройка чистого macOS одной командой:
#
#   curl -fsSL https://raw.githubusercontent.com/rajivgeraev/dotfiles/main/bootstrap.sh -o /tmp/bootstrap.sh && zsh /tmp/bootstrap.sh
#
# Именно через -o, а не `curl … | zsh`: при конвейере скрипт читается из stdin,
# и `read` ниже съел бы собственный текст вместо нажатия Enter.
#
# Скрипт самодостаточен — репозиторий он клонирует сам. Если же его запустили
# из уже склонированного репозитория (`./bootstrap.sh`), работа идёт с этим
# каталогом и ничего никуда не клонируется.

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header()  { echo -e "\n${CYAN}${BOLD}==> $1${NC}\n"; }
print_step()    { echo -e "${YELLOW}${BOLD}  -> $1${NC}"; }
print_success() { echo -e "${GREEN}${BOLD}  ok $1${NC}"; }
print_error()   { echo -e "${RED}${BOLD} err $1${NC}"; }
print_info()    { echo -e "${BLUE}${BOLD}    $1${NC}"; }

GITHUB_USER="rajivgeraev"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}${BOLD}🚀 Starting environment bootstrap...${NC}"

# ==========================================
# 0. Prerequisites
# ==========================================
print_header "🔧 Prerequisites"

# Xcode CLT нужны раньше всего: без них нет git, а значит нечем клонировать
# репозиторий и нечем собирать формулы Homebrew.
if ! xcode-select -p >/dev/null 2>&1; then
  print_step "Installing Xcode Command Line Tools..."
  xcode-select --install
  print_info "Please click Install in the dialog, then press Enter"
  read -r
  while ! xcode-select -p >/dev/null 2>&1; do
    sleep 2
  done
fi
print_success "Xcode CLT ready"

# ==========================================
# 1. Homebrew
# ==========================================
print_header "🍺 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  print_step "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  print_success "Homebrew already installed"
fi

# Свежеустановленный brew ещё не в PATH этого процесса. Префикс зависит от
# архитектуры: /opt/homebrew на Apple Silicon, /usr/local на Intel.
if ! command -v brew >/dev/null 2>&1; then
  for brew_prefix in /opt/homebrew /usr/local; do
    if [[ -x "$brew_prefix/bin/brew" ]]; then
      eval "$("$brew_prefix/bin/brew" shellenv)"
      break
    fi
  done
fi

if ! command -v brew >/dev/null 2>&1; then
  print_error "Homebrew not found in PATH after install"
  exit 1
fi

# ==========================================
# 2. chezmoi
# ==========================================
# Ставится отдельно и раньше Brewfile: сам Brewfile лежит в репозитории, а
# достать репозиторий без chezmoi нечем. В Brewfile chezmoi тоже есть — на
# шаге 4 brew bundle просто увидит, что он уже стоит.
print_header "📦 chezmoi"
if ! command -v chezmoi >/dev/null 2>&1; then
  print_step "Installing chezmoi..."
  brew install chezmoi
else
  print_success "chezmoi already installed"
fi

# ==========================================
# 3. Dotfiles (init)
# ==========================================
# Только init, без --apply. Применять сейчас нельзя: run_onchange-скрипт для
# кеша bat не нашёл бы bat, пометил бы себя выполненным — и после установки
# пакетов уже не перезапустился бы, оставив тему неприменённой.
print_header "📁 Dotfiles"

if [[ -f "$SCRIPT_DIR/Brewfile" ]]; then
  # Запуск из склонированного репозитория — работаем с ним.
  REPO_DIR="$SCRIPT_DIR"
  print_info "Источник: $REPO_DIR (локальный клон)"
  chezmoi init --source "$REPO_DIR"
  # Каталог источника не сохраняется в конфиг, поэтому обычные вызовы chezmoi
  # будут смотреть в ~/.local/share/chezmoi. Если клон лежит не там — сказать
  # об этом сразу, а не оставлять человека гадать, почему apply ничего не видит.
  if [[ "$REPO_DIR" != "$HOME/.local/share/chezmoi" ]]; then
    print_info "Это не стандартный каталог chezmoi — дальше нужен --source \"$REPO_DIR\""
  fi
else
  # Скрипт скачан отдельно — репозиторий клонирует chezmoi.
  print_step "Cloning $GITHUB_USER/dotfiles..."
  chezmoi init "$GITHUB_USER"
  REPO_DIR="$(chezmoi source-path)"
  print_info "Источник: $REPO_DIR"
fi
print_success "Dotfiles fetched"

# ==========================================
# 4. Homebrew Packages
# ==========================================
print_header "📦 Homebrew Packages"
BREWFILE_PATH="$REPO_DIR/Brewfile"
if [[ ! -f "$BREWFILE_PATH" ]]; then
  print_error "Brewfile not found at $BREWFILE_PATH"
  exit 1
fi
# --verbose: без него brew bundle молчит минутами на каждом каске, и в VM это
# неотличимо от зависания. С ним видно, что именно скачивается прямо сейчас.
print_info "К установке: $(grep -cE '^(brew|cask) ' "$BREWFILE_PATH") пакетов"
brew bundle --verbose --file="$BREWFILE_PATH"
print_success "Brew packages synced"

# ==========================================
# 5. Apply dotfiles
# ==========================================
# Теперь, когда пакеты на месте: расшифровывается age-ключ, раскладываются
# конфиги и секреты, отрабатывают run_onchange-скрипты.
print_header "🔐 Applying dotfiles"
print_info "Сейчас потребуется парольная фраза от age-ключа"
chezmoi apply --source "$REPO_DIR"
print_success "Dotfiles applied"

# ==========================================
# 6. Workspace
# ==========================================
print_header "🏗️ Workspace"
mkdir -p "$HOME/dev"
print_success "$HOME/dev created"

# ==========================================
# 7. macOS Defaults
# ==========================================
# Последним шагом: настройки чисто косметические, и если что-то упадёт раньше,
# разбираться нужно с установкой, а не с положением path bar в Finder.
print_header "🍎 macOS Defaults"
MACOS_DEFAULTS="$REPO_DIR/macos-defaults.sh"
if [[ -x "$MACOS_DEFAULTS" ]]; then
  "$MACOS_DEFAULTS"
else
  print_error "macos-defaults.sh not found at $MACOS_DEFAULTS"
fi

# ==========================================
# Done
# ==========================================
echo -e "\n${GREEN}${BOLD}🎉 Bootstrap complete.${NC}"
echo -e "${YELLOW}Restart your terminal to pick up the new shell configuration.${NC}\n"
