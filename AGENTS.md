# Dotfiles Agent Guide

This repository manages personal shell configuration, an Ubuntu bootstrap script, and small workflow helpers. Keep changes practical, portable, and safe to source from an interactive shell. The primary target is **Ubuntu/Linux with bash as the primary shell**; zsh is supported as an optional secondary shell.

## Repository Purpose

- `README.md` is the user-facing setup guide and should describe the current behavior of the scripts.
- `my_shell_config.sh` is the **main entry point**, sourced by `~/.bashrc` (and optionally `~/.zshrc`).
- `common_init_funcs.sh` contains shared setup helpers and loads `secrets.sh` when present.
- `shell/` contains modular shell configuration:
  - `paths.sh`: PATH helpers (`add_to_path`) and path entries.
  - `exports.sh`: environment variables.
  - `aliases.sh`: aliases only.
  - `functions.sh`: reusable shell functions.
- `init_ubuntu.sh` bootstraps Ubuntu/Linux: it prefers Linuxbrew (Homebrew on Linux) and falls back to `apt` when brew is unavailable, then installs tooling and links config files.
- `config.example.sh` is the template for local private configuration.
- `secrets.sh` is a local-only file and must not be committed.

## Editing Rules

- **bash is the primary shell.** Write shell that sources cleanly under bash first. Prefer POSIX-compatible constructs where reasonable.
- Shell files are sourced by users. Avoid top-level commands that are slow, destructive, network-dependent, or noisy during shell startup.
- Keep secrets, real internal hosts, personal tokens, private URLs, employee IDs, and machine-specific paths out of tracked examples and docs. Use placeholders such as `example.com`, `127.0.0.1`, `your_name`, or `your-username`.
- Respect `DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}` so the repository can be checked out somewhere else. This default must be used everywhere.
- Quote variable expansions that may contain spaces, especially paths and scp arguments.
- Do not add aliases that hide destructive commands unless the behavior is already intentional and documented.
- If adding a new user-visible script, update `README.md` with usage and prerequisites.

## Shell Design

- Put PATH changes in `shell/paths.sh`, environment exports in `shell/exports.sh`, aliases in `shell/aliases.sh`, and functions in `shell/functions.sh`.
- `shell/paths.sh` should avoid adding duplicate PATH entries (the `add_to_path` helper guards against this).
- zsh-only commands such as `bindkey` or `compdef` must be guarded with `command -v <name> >/dev/null 2>&1` so bash can still source `my_shell_config.sh` without errors.
- Linux lacks `pbcopy`/`pbpaste`; provide portable shims backed by `xclip` or `xsel`, falling back to a silent no-op when neither is installed.
- Commands that depend on optional tools such as `eza`, `fzf`, `xclip`, `gsed`, `plantuml`, `hexo`, `zoxide`, or `nvm` should fail gracefully or be clearly documented.

## Bootstrap Rules

- `init_ubuntu.sh` may install software and modify user-level config, but keep those actions visible with clear echo output.
- Prefer Linuxbrew when available; fall back to `apt` (`sudo apt-get install ...`) otherwise. Guard every tool install so a missing package manager does not abort the whole run.
- Do not run bootstrap scripts automatically during analysis. They install software and change the user environment.
- When changing bootstrap behavior, check `init_ubuntu.sh`, `README.md`, and the shell modules for consistency.

## Validation

Run the narrowest useful checks after changes:

```bash
bash -n my_shell_config.sh common_init_funcs.sh init_ubuntu.sh config.example.sh shell/paths.sh shell/exports.sh shell/aliases.sh shell/functions.sh
```

For startup-related changes, also test sourcing in a subshell:

```bash
bash -c 'DOTFILES_ROOT=$PWD source ./my_shell_config.sh'
```

Do not run `./init_ubuntu.sh`, package-manager installs, or service toggles unless the user explicitly asks.
