# Rajiv's Dotfiles ![](https://img.shields.io/badge/macOS-Dotfiles-blue)

[![chezmoi](https://img.shields.io/badge/CI-chezmoi-purple)](https://github.com/rajivgeraev/dotfiles) [![Shell](https://img.shields.io/badge/Shell-Zsh-orange)](https://www.zsh.org/) [![Terminal](https://img.shields.io/badge/Terminal-Ghostty-black)](https://ghostty.org/)

---

# Rajiv's Dotfiles

My personal macOS development environment configuration, managed with [chezmoi](https://www.chezmoi.io/).

## Table of Contents

- [Quick Setup](#quick-setup-for-a-fresh-mac)
- [Tech Stack](#tech-stack--tools)
- [Quick Reference](#quick-reference)
- [Directory Structure](#directory-structure)
- [Configuration Highlights](#configuration-highlights)
- [Secrets Management](#secrets-management)
- [AI Integration](#ai-integration)
- [Updating](#updating)

---

## Important Warning

**This script will reset your terminal and shell configuration!**

Before running, please:
1. Backup your existing configs: `~/.zshenv`, `~/.config/zsh/`, `~/.config/git/`, `~/.config/ghostty/`
2. Understand what this script does (review `bootstrap.sh` and the directory structure above)
3. I am not responsible for any data loss or configuration issues

---

## Quick Setup (For a fresh Mac)

A completely new, empty machine is set up with a single command. `bootstrap.sh` is
self-contained: it installs chezmoi and clones this repository itself.

```bash
curl -fsSL https://raw.githubusercontent.com/rajivgeraev/dotfiles/main/bootstrap.sh -o /tmp/bootstrap.sh && zsh /tmp/bootstrap.sh
```

Download it with `-o` rather than piping into `zsh`: a pipe hands the script's own
text to `read`, which breaks the step that waits for the Xcode CLT installer.

Two moments need you at the keyboard: the Xcode Command Line Tools dialog (click
Install, then press Enter in the terminal), and the age passphrase, asked once
when the dotfiles are applied.

*(Note: the repository is cloned over HTTPS. If you plan to push changes back to
GitHub later, switch the git remote to SSH inside `~/.local/share/chezmoi` — the
key is restored by chezmoi as part of the run.)*

### What `bootstrap.sh` does

1. Installs **Xcode Command Line Tools** (if missing)
2. Installs **Homebrew** (if missing)
3. Installs **chezmoi**, then clones this repository with `chezmoi init` — without applying it yet
4. Installs tools and applications via **Brewfile**
5. Applies the dotfiles: decrypts the age key, lays out configs and secrets, runs the repository scripts
6. Creates the `~/dev` workspace
7. Applies **macOS defaults** via `macos-defaults.sh`

The order is deliberate. Applying before the Brewfile would run the repository's
`run_onchange` scripts against a machine with nothing installed — the bat cache
script would find no `bat`, mark itself done, and never run again.

Running `./bootstrap.sh` from an already cloned repository works too: it uses that
directory as-is instead of cloning.

### After the bootstrap

Three things cannot be automated and are left to do by hand.

**1. Sign in to Atuin.** The encryption key is restored with the other secrets, but
the session is not — the CLI has no token-based login, and the account password is
deliberately not stored here. Without this step the cloud history never arrives, no
matter how long you wait:

```bash
atuin login -u rajivgeraev -k "$(cat ~/.local/share/atuin/key)"
atuin sync
```

The password is asked interactively. `atuin login` is supposed to sync on its own,
but only at the next periodic sync — up to 5 minutes later; the explicit `atuin sync`
pulls everything right away.

**2. Grant Karabiner-Elements its macOS permissions.** The rules are already in
place, but Accessibility and Driver Extensions can only be granted through System
Settings — see [`karabiner-recovery.md`](karabiner-recovery.md).

**3. Open Ghostty.** On first launch antidote downloads the zsh plugins.

## Tech Stack & Tools

- **Shell**: Zsh (modular config, plugins via [antidote](https://antidote.sh/))
- **Terminal**: [Ghostty](https://ghostty.org/) (JetBrainsMono Nerd Font, Catppuccin Mocha)
- **Prompt**: [Starship](https://starship.rs/) (nerd font, multi-language)
- **Editor**: [Zed](https://zed.dev/)
- **AI Tools**: Claude Code
- **Core CLI Tools**:
  - `zoxide` (smart `cd`)
  - `eza` (modern `ls`)
  - `bat` (modern `cat`)
  - `atuin` (shell history, synced and end-to-end encrypted)
  - `fzf` + `ripgrep` (fuzzy search)
  - `yazi` (terminal file manager)
  - `gh` (GitHub CLI)
  - `rclone` (cloud storage sync)
  - `age` (file encryption)
- **Keyboard**: Karabiner-Elements (Cmd taps switch input source, Caps Lock disabled)

## Quick Reference

```bash
chezmoi apply                     # Apply dotfiles to $HOME
chezmoi update                    # Pull latest & apply
chezmoi diff                      # Preview changes
chezmoi edit ~/.config/zsh/.zshrc # Edit a managed file
chezmoi add --encrypt ~/.ssh/key  # Track a new secret, encrypted
```

## Directory Structure

```text
.
├── bootstrap.sh                   # Environment setup script (entry point)
├── macos-defaults.sh              # macOS system settings, run last by bootstrap
├── sync-mac.sh                    # One-way rclone sync to Hetzner Storage Box
├── Brewfile                       # Homebrew dependencies
├── karabiner-recovery.md          # How to rebuild the keyboard rules
├── key.txt.age                    # age key, protected by a passphrase
├── .chezmoiexternal.toml          # Catppuccin themes fetched from upstream
├── .chezmoiscripts/
│   ├── run_onchange_before_decrypt-private-key.sh.tmpl   # Restores the age key
│   └── run_onchange_after_rebuild-bat-cache.sh.tmpl      # Rebuilds the bat cache
├── dot_zshenv                     # XDG variables and ZDOTDIR
├── dot_config/
│   ├── bat/                       # Config + custom zsh-plugins syntax
│   ├── ghostty/config.ghostty     # Ghostty terminal config
│   ├── git/                       # config.tmpl + global ignore
│   ├── private_atuin/             # Shell history settings
│   ├── private_karabiner/         # Keyboard rules
│   ├── rclone/                    # encrypted
│   ├── ripgrep/config             # Search defaults
│   ├── starship/starship.toml     # Prompt config
│   ├── zed/                       # Editor settings
│   └── zsh/
│       ├── dot_zshrc              # Zsh entry point
│       ├── dot_zprofile           # Homebrew shellenv
│       ├── dot_zsh_plugins.txt    # antidote, phase 1 (before compinit)
│       ├── dot_zsh_plugins_post.txt # antidote, phase 2 (after compinit)
│       └── conf.d/                # Subsystem modules, loaded by explicit list
├── dot_local/share/private_atuin/ # encrypted
├── private_dot_ssh/               # encrypted
└── dot_claude/settings.json       # Claude Code settings
```

## Configuration Highlights

### Zsh Modular Setup

Load order: `~/.zshenv` (XDG variables, `ZDOTDIR`) → `dot_config/zsh/dot_zshrc` →
modules from `conf.d/`.

Modules are listed explicitly in `.zshrc` rather than globbed, so a file left in
`conf.d/` does nothing until it is added to the list. Each module guards itself
with `command -v`, so a missing tool is skipped instead of erroring.

Loading happens in **two phases**, split by `compinit`. This is a requirement of
fzf-tab: it must load after the completion system exists, but before the plugins
that wrap zle widgets. Hence antidote is split in two as well.

| Module | Purpose |
|--------|---------|
| `antidote-pre.zsh` | Phase 1: antidote itself + completion plugins (`kind:fpath`) |
| `antidote-post.zsh` | Phase 2: everything that needs a ready completion system |
| `atuin.zsh` | Shell history |
| `zoxide.zsh` | Smart `cd` |
| `starship.zsh` | Prompt |
| `bat.zsh` | `cat` alias + fzf-tab preview |
| `eza.zsh` | `ls` / `ll` aliases |
| `rg.zsh` | Points ripgrep at its config file |

Zsh plugins via antidote — phase 1: `zsh-completions`, `zsh-claudecode-completion`.
Phase 2, in order: `fzf-tab`, `zsh-autopair`, `zsh-window-title`,
`zsh-autosuggestions`, `zsh-syntax-highlighting`.

History lives in `$XDG_STATE_HOME/zsh/history` — it is state, not configuration.

### Claude Code

- Model defaults to `opus`, interface language Russian, dark theme
- Permissions default to `auto`; voice input enabled in hold mode
- Only `settings.json` is tracked — sessions, cache and history stay local

### Terminal (Ghostty)

- Font: JetBrainsMono Nerd Font
- Theme: Catppuccin Mocha
- Translucent background with macOS blur
- Quick terminal on top of the screen, toggled with `Cmd+\` globally
- Shell integration for zsh

## Secrets Management

Secrets live in this repository, but only as ciphertext — encrypted with
[age](https://age-encryption.org), following chezmoi's own recipe. Nothing is
stored in the clear, not even the ssh config or the public key.

The age key itself is encrypted with a passphrase and committed as `key.txt.age`.
On a new machine, `run_onchange_before_decrypt-private-key.sh` decrypts it into
`~/.config/chezmoi/key.txt`, asking for the passphrase once. Everything after that
is automatic: chezmoi puts each secret at its path with the right mode, so there is
nothing to copy by hand and no `chmod` to remember.

Currently encrypted:

| File | Restored to |
|------|-------------|
| `private_dot_ssh/encrypted_private_id_ed25519_gh.age` | `~/.ssh/id_ed25519_gh` (0600) |
| `private_dot_ssh/encrypted_id_ed25519_gh.pub.age` | `~/.ssh/id_ed25519_gh.pub` |
| `private_dot_ssh/encrypted_config.age` | `~/.ssh/config` |
| `dot_config/rclone/encrypted_private_rclone.conf.age` | `~/.config/rclone/rclone.conf` (0600) |
| `dot_local/share/private_atuin/encrypted_private_key.age` | `~/.local/share/atuin/key` (0600) |

To track a new secret:

```bash
chezmoi add --encrypt ~/.config/something/secret.conf
```

**The passphrase is the single point of failure.** Write it down somewhere outside
this repository — losing it means losing the Atuin key, which cannot be
regenerated. The decrypted `~/.config/chezmoi/key.txt` must never be committed.

## AI Integration

- [Claude Code](https://github.com/anthropics/claude-code) — settings tracked in `dot_claude/settings.json`
- Zsh completions for `claude` come from the `zsh-claudecode-completion` plugin
- `CLAUDE.md` in the repository root documents the layout for Claude Code itself

## Updating

To pull the latest changes and apply them:

```bash
chezmoi update
```
