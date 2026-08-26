#!/bin/zsh

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}${BOLD}🚀 Starting environment bootstrap...${NC}"

# ==========================================
# 0. Prerequisites
# ==========================================
print_header "🔧 Prerequisites"

# Check Xcode Command Line Tools
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

# Load brew into current shell session
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  print_error "Homebrew not found in PATH after install"
  exit 1
fi

# ==========================================
# 2. Homebrew Packages
# ==========================================
print_header "📦 Homebrew Packages"
BREWFILE_PATH="$SCRIPT_DIR/Brewfile"
if [[ ! -f "$BREWFILE_PATH" ]]; then
  print_error "Brewfile not found at $BREWFILE_PATH"
  exit 1
fi
brew bundle --file="$BREWFILE_PATH"
print_success "Brew packages synced"

# ==========================================
# 3. Dotfiles (chezmoi)
# ==========================================
print_header "📁 Dotfiles (chezmoi)"
CHEZMOI_REPO="https://github.com/rajivgeraev/dotfiles.git"
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi init "$CHEZMOI_REPO" --apply
else
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init "$CHEZMOI_REPO" --apply
fi
print_success "Dotfiles applied"

SECRETS_FILE="$HOME/.config/zsh/.secret"
if [[ ! -f "$SECRETS_FILE" ]]; then
  mkdir -p "$(dirname "$SECRETS_FILE")"
  touch "$SECRETS_FILE"
  print_info "⚠️  Created empty $SECRETS_FILE — sync your secrets manually"
fi

# ==========================================
# 4. Workspace
# ==========================================
print_header "🏗️ Workspace"
mkdir -p "$HOME/dev"
print_success "$HOME/dev created"

# ==========================================
# 5. macOS Defaults
# ==========================================
# Последним шагом: настройки чисто косметические, и если что-то упадёт раньше,
# разбираться нужно с установкой, а не с положением path bar в Finder.
MACOS_DEFAULTS="$SCRIPT_DIR/macos-defaults.sh"
if [[ -x "$MACOS_DEFAULTS" ]]; then
  "$MACOS_DEFAULTS"
else
  print_error "macos-defaults.sh not found at $MACOS_DEFAULTS"
fi

# ==========================================
# Done
# ==========================================
echo -e "\n${GREEN}${BOLD}🎉 Bootstrap complete.${NC}"
echo -e "${YELLOW}Run ${BOLD}source ~/.zshrc${NC}${YELLOW} or restart your terminal to apply changes.${NC}\n"
