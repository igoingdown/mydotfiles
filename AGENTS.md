# Dotfiles Agent Guide

This repository manages personal shell configuration, macOS bootstrap scripts, and small workflow helpers. Keep changes practical, portable, and safe to source from an interactive shell.

## Repository Purpose

- `README.md` is the user-facing setup guide and should describe the current behavior of the scripts.
- `my_shell_config.sh` is the main entry point sourced by `~/.zshrc` or `~/.bashrc`.
- `common_init_funcs.sh` contains shared setup helpers and loads `secrets.sh` when present.
- `shell/` contains modular shell configuration:
  - `paths.sh`: PATH helpers and path entries.
  - `exports.sh`: environment variables.
  - `aliases.sh`: aliases only.
  - `functions.sh`: reusable shell functions.
- `init_mac.sh` bootstraps macOS with Homebrew, Brewfile dependencies, Oh My Zsh, Vundle, and config files.
- `config.example.sh` is the template for local private configuration.
- `secrets.sh` and `.dotfiles_secrets` are local-only files and must not be committed.

## Editing Rules

- Prefer POSIX-compatible shell where reasonable, but preserve zsh-specific behavior for scripts with `#!/bin/zsh`.
- Shell files are sourced by users. Avoid top-level commands that are slow, destructive, network-dependent, or noisy during shell startup.
- Keep secrets, real internal hosts, personal tokens, private URLs, employee IDs, and machine-specific paths out of tracked examples and docs. Use placeholders such as `example.com`, `10.0.0.1`, `your_name`, or `sample-*`.
- Respect `DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}` so the repository can be checked out somewhere else.
- Quote variable expansions that may contain spaces, especially paths and scp arguments.
- Do not add aliases that hide destructive commands unless the behavior is already intentional and documented.
- If adding a new user-visible script, update `README.md` with usage and prerequisites.

## Shell Design

- Put PATH changes in `shell/paths.sh`, environment exports in `shell/exports.sh`, aliases in `shell/aliases.sh`, and functions in `shell/functions.sh`.
- `shell/paths.sh` should avoid adding duplicate PATH entries.
- zsh-only commands such as `bindkey` must be guarded so bash can still source `my_shell_config.sh`.
- Proxy helpers should export standard URL forms, for example `http://127.0.0.1:8080` and `socks5://127.0.0.1:1080`.
- Commands that depend on optional tools such as `eza`, `fzf`, `pbcopy`, `gsed`, `plantuml`, `hexo`, or `nvm` should fail gracefully or be clearly documented.

## Bootstrap Rules

- `init_mac.sh` may install software and modify user-level config, but keep those actions visible with clear echo output.
- Do not run bootstrap scripts automatically during analysis. They install software and change the user environment.
- When changing bootstrap behavior, check `Brewfile`, `README.md`, and the shell modules for consistency.

## Validation

Run the narrowest useful checks after changes:

```bash
bash -n my_shell_config.sh common_init_funcs.sh init_mac.sh config.example.sh shell/paths.sh shell/exports.sh shell/aliases.sh shell/functions.sh bbs_conf.sh
zsh -n my_shell_config.sh common_init_funcs.sh init_mac.sh shell/paths.sh shell/exports.sh shell/aliases.sh shell/functions.sh bbs_conf.sh proxy_toggle.sh
```

For startup-related changes, also test sourcing:

```bash
bash -c 'DOTFILES_ROOT=$PWD source ./my_shell_config.sh'
zsh -c 'DOTFILES_ROOT=$PWD source ./my_shell_config.sh'
```

Do not run `./init_mac.sh`, Homebrew installs, or service toggles unless the user explicitly asks.
