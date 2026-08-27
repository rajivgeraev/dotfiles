# CLAUDE.md

This file gives Claude Code (claude.ai/code) the context it needs to work in this
repository.

## What this is

A macOS dotfiles repository managed with [chezmoi](https://www.chezmoi.io), paired
with Homebrew. This is chezmoi's *source directory* — files here follow chezmoi's
naming conventions and are not the same files that end up on disk. There is no
build, linter or test suite; changes are verified by rendering, diffing and
applying through chezmoi, and by actually using the resulting shell config.

## chezmoi naming conventions

Source files follow standard chezmoi naming: `dot_foo` → `~/.foo`, `private_foo` →
mode `0600`, `*.tmpl` → rendered as a Go template before writing, `encrypted_*.age`
→ decrypted with age on apply (see Encryption below), `run_once_*`/`run_onchange_*`
combined with `before_`/`after_` → scripts. The general reference for chezmoi's
attributes lives in project memory (rebuilt per machine — see the last section)
rather than being duplicated here.

- `.chezmoiignore` excludes the files that live here for documentation or tooling
  but are not dotfiles: `README.md`, `CLAUDE.md`, `Brewfile`, `karabiner-recovery.md`,
  `bootstrap.sh`, `macos-defaults.sh`, `sync-mac.sh`, `key.txt.age`. Anything in the
  repository root without a `dot_` prefix **must** be listed there — otherwise
  chezmoi applies it to `$HOME` verbatim. Both shell scripts and `key.txt.age` were
  caught exactly this way.
- `.chezmoi.toml.tmpl` is the template for chezmoi's own config (rendered once by
  `chezmoi init` into `~/.config/chezmoi/chezmoi.toml`), holding the age
  `identity`/`recipient` and `[data]` for templates (name/email).

Config for an optional tool is gated at **shell runtime**, not at chezmoi's template
render time — deliberately not via `{{ if lookPath }}`/`{{ if stat }}` in a `.tmpl`.
Each tool's shell integration lives in its own `dot_config/zsh/conf.d/<tool>.zsh`
with the gate on the first line (`command -v <tool> >/dev/null 2>&1 || return`, or
`[[ -d ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/<formula> ]] || return` for a
Homebrew-installed directory, as done for antidote). `dot_zshrc` lists which
`conf.d` files to source in explicit arrays (`typeset -a`) rather than globbing —
the arrays act as an allowlist, so a file left in `conf.d/` is never picked up until
it is added to the list.

Sourcing happens in **two phases** with `compinit` between them: fzf-tab must load
after `compinit` but before the plugins that wrap zle widgets. Phase 1
(`zsh_conf_pre`, currently only `antidote-pre`) loads `.zsh_plugins.txt`, which
holds only completion plugins annotated `kind:fpath`. Phase 2 (`zsh_conf_post`,
starting with `antidote-post`) loads `.zsh_plugins_post.txt`: fzf-tab first,
autosuggestions and syntax-highlighting last. Within a phase the file order does not
matter; the line order inside `.zsh_plugins_post.txt` does. Follow this pattern when
adding config for a new optional CLI tool. A `command -v` check re-evaluates on every
shell start, so it is correct from the first run regardless of install order —
unlike `lookPath`, which inspects the `$PATH` of chezmoi's own process, frozen when
`chezmoi apply` started.

## Application order

Everyday commands (`chezmoi diff`/`apply`/`edit`/`add`/`update`) are in `README.md`
and not repeated here. What matters for correctness and is *specific to this
repository*:

Installing software is **not** chezmoi's job here — `bootstrap.sh` owns it. That is
a deliberate split: chezmoi manages files, bootstrap installs packages and configures
the system. Do not reintroduce a `run_once_before_install-brewfile` script; it would
duplicate what bootstrap already does.

`bootstrap.sh` is self-contained and runs: Xcode CLT → Homebrew → chezmoi →
`chezmoi init` (no `--apply`) → `brew bundle` → `chezmoi apply` → `~/dev` →
`macos-defaults.sh`. The order is load-bearing. Applying before the Brewfile would
run `run_onchange` scripts on a machine with nothing installed — the bat cache script
would find no `bat`, exit 0, and be recorded as done, never running again.

Within `chezmoi apply`, scripts live in `.chezmoiscripts/`, so they execute without
creating target-state entries:

1. `run_onchange_before_decrypt-private-key.sh.tmpl` — restores the age key (see
   Encryption). `before_` is required: the key must exist before any `encrypted_*`
   file is applied.
2. regular files, templates and externals.
3. `run_onchange_after_rebuild-bat-cache.sh.tmpl` — `bat cache --build`, triggered by
   the hashes of `.chezmoiexternal.toml` and the syntax file. `after_` is required:
   both the themes and the syntax file must already be on disk.

Themes are declared in `.chezmoiexternal.toml` rather than fetched by a script, so
chezmoi caches them, verifies them on every apply/diff/verify, and a network failure
no longer aborts the whole apply.

Scripts must call `chezmoi` through `{{ .chezmoi.executable }}`, never by bare name.
On a fresh machine the binary may sit outside `$PATH`, and a bare `chezmoi` fails with
exit 127, aborting the apply before a single file is written.

## Encryption (age)

Secrets are encrypted with [age](https://age-encryption.org) — the general mechanism
(`recipient` = public key = encrypt, `identity` = private key = decrypt) is standard
chezmoi/age behaviour. What is project-specific and expensive to get wrong:

- The repository is **public**. Everything sensitive must be encrypted before it is
  committed — including things that feel harmless, such as the ssh config or a public
  key. Never add a secret without `--encrypt`.
- The age key itself is committed as `key.txt.age`, encrypted with a **passphrase**.
  `run_onchange_before_decrypt-private-key.sh.tmpl` decrypts it into
  `~/.config/chezmoi/key.txt` on first run, asking for the passphrase once. The
  decrypted key never gets committed. This follows chezmoi's documented recipe and is
  what makes restoring a machine a single command.
- The passphrase is the single point of failure: it is not stored anywhere in this
  repository, and losing it means losing
  `dot_local/share/private_atuin/encrypted_private_key.age` — the Atuin E2E key, which
  cannot be regenerated. The ssh key and `rclone.conf` could be recreated by hand;
  that one could not.
- Atuin needs two separate things: the encryption key (restored by chezmoi) and a
  session (only `atuin login` creates one). The account password is deliberately not
  stored here — `atuin login` has no token auth, only `-u`/`-p`/`-k`/`-t`, verified
  against the installed CLI's `--help`. Restoring the key alone leaves the cloud
  history unfetched; `README.md` documents the manual step.
- Key rotation: generate a new age pair, run
  `chezmoi re-add --re-encrypt --age-recipient <new_public>` to re-encrypt every
  `encrypted_*` file from the plaintext already on disk, then immediately switch
  `identity`/`recipient` in `~/.config/chezmoi/chezmoi.toml` and `recipient` in
  `.chezmoi.toml.tmpl` before running `chezmoi diff`/`apply` again. Re-encrypt
  `key.txt.age` from the new key too. Verify with `chezmoi verify`.

## Managed tools/stack

- Shell: zsh with antidote (plugin manager), starship (prompt), atuin (shell history,
  Catppuccin Mocha Mauve theme, cloud sync — see Encryption for its key).
- The full CLI/GUI package list is in `Brewfile` and is not duplicated here: read it
  directly rather than assuming this file is in sync with it. Packages installed on
  the machine but absent from `Brewfile` are intentionally not tracked.
- Among GUI casks, chezmoi manages config for Ghostty, Zed (`dot_config/zed/`),
  Claude Code's global settings (`dot_claude/settings.json` — global preferences only:
  `theme`, `tui`, `model`, `language`, `voice`; never the rest of `~/.claude/`, which
  is session and telemetry state) and Karabiner-Elements
  (`dot_config/private_karabiner/private_karabiner.json` — Cmd-tap layout switching;
  granting macOS Accessibility and driver-extension permissions is manual and
  documented in `karabiner-recovery.md`). Other apps had no config worth versioning.
  Before concluding the same about a new cask, check its actual preferences domain and
  Application Support directory.
- `dot_zshenv` holds the environment variables every zsh must see: the four XDG
  directories and `$ZDOTDIR`, derived from `XDG_CONFIG_HOME`. They belong here rather
  than in `dot_zshrc`, which only interactive shells read — scripts, LaunchAgents and
  `zsh -c` would otherwise be left without them. Keep this file free of aliases,
  output and slow calls.
- `$ZDOTDIR` is `~/.config/zsh`, so zsh's own dotfiles live in `dot_config/zsh/`
  (`dot_zprofile`, `dot_zshrc`, `conf.d/*.zsh`, `dot_zsh_plugins{,_post}.txt`), not in
  `~/.zshrc`.
- `zconf` (defined at the end of `dot_zshrc`) opens the zshrc source via
  `chezmoi edit`; `zconf -r` re-sources the current one.
- Git identity comes from `dot_config/git/config.tmpl` using `.name`/`.email` declared
  in `[data]` of `.chezmoi.toml.tmpl` — no separate manual step, and `bootstrap.sh`
  deliberately does not run `git config --global`, which would write `~/.gitconfig` and
  shadow the XDG file.
- Global git ignores live in `dot_config/git/ignore`, which git reads on its own — no
  `core.excludesFile` needed.

## Claude Code memory for this project

Auto memory stays in Claude Code's default location
(`~/.claude/projects/<project>/memory/`) — deliberately **not** moved into the
repository. The default is already project-scoped, shared across every session started
in this directory, and never reaches git.

## New machine / new session bootstrap

`README.md` ends its restore procedure with running `claude` in this directory on the
freshly restored machine. Memory (see above) is machine-local and will not exist there
yet, although this file will, since it arrives with the git clone.

If project memory is empty or missing topics at the start of a session here, build it
in this order, once per machine (check what already exists first; do not re-research a
topic that already has a note):

1. **Claude Code itself first.** Find current official best practices (`CLAUDE.md`
   structure and size, auto memory conventions, effective working patterns) in
   Anthropic's documentation and save them before anything else — they shape how the
   rest of the bootstrap and subsequent work should go.
2. **Every tool in this repository, not just chezmoi.** Read `Brewfile` directly for
   the current list rather than hardcoding it here. For chezmoi and each tool, check
   whether a note already exists; for those that do not, find current documentation and
   save one. Scale the effort to how much the tool's behaviour and defaults actually
   matter here: chezmoi, atuin, starship, antidote and yazi deserve real research;
   stable, well-known tools (curl, rsync, git, gh) need only a quick syntax check.

The point is not to rely on possibly outdated training knowledge: defaults and
features change between releases. Memory staying outside git and being rebuilt per
machine is deliberate — the cost is paying for this research once per new machine
rather than once per session.

## Language note

`README.md` and this file are written in English. Comments inside configs and scripts
are in Russian — that is the existing convention, follow it when editing them. Commit
messages are in English.
