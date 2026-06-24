# my dot files

This repository manages my dot configuration files, scripts, and development environment settings for **Ubuntu / Linux** with **bash** as the primary shell (zsh is supported as an optional secondary shell).

## Quick Start

### 1. Clone the repository

```bash
git clone git@github.com:<your-username>/<your-dotfiles>.git ~/github/my_dot_files
cd ~/github/my_dot_files
```

*Note: scripts support a dynamic root via `$DOTFILES_ROOT` (default `$HOME/github/my_dot_files`). Keeping the checkout at `~/github/my_dot_files` is recommended for maximum compatibility.*

### 2. Configure secrets

Copy the example configuration file and fill in your private information (API keys, internal IPs, personal IDs, etc.).

```bash
cp config.example.sh secrets.sh
vim secrets.sh
```

**Important:** `secrets.sh` is git-ignored. Never commit your secrets.

### 3. Install dependencies and initialize

Run the Ubuntu initialization script to install tooling and link configuration files.

```bash
./init_ubuntu.sh
```

This script:

- Prefers **Linuxbrew** (Homebrew on Linux) when available and falls back to **`apt`** otherwise.
- Installs core tooling (zsh, Go, search/utility tools) using whichever package manager is present.
- **Appends** the entry line to `~/.bashrc` (never overwriting it) and symlinks `.vimrc` / `.tmux.conf` into your home directory only when they are absent.

### 4. Load shell configuration

Add the following line to your `~/.bashrc` (or `~/.zshrc`) to load the configuration:

```bash
source ~/github/my_dot_files/my_shell_config.sh
```

## Project Structure

```text
.
├── my_shell_config.sh    # Main shell configuration entry point (source this)
├── common_init_funcs.sh  # Shared helpers + loads secrets.sh
├── init_ubuntu.sh        # Ubuntu/Linux initialization (Linuxbrew preferred, apt fallback)
├── config.example.sh     # Template for secrets & config (copy to secrets.sh)
├── shell/                # Modular shell configuration
│   ├── paths.sh          # PATH modifications (add_to_path helper)
│   ├── exports.sh        # Environment variables
│   ├── aliases.sh        # Shell aliases
│   └── functions.sh      # Shell functions
├── .bashrc               # bash rc (primary shell)
├── .zshrc                # zsh rc (optional secondary shell)
├── .vimrc                # Vim configuration
├── .tmux.conf            # tmux configuration
├── AGENTS.md             # Contributor / agent guide
├── README.md             # This file
└── LICENSE               # License
```

## Features and Configuration

### Shell configuration (`my_shell_config.sh`)

The entry point loads the modular `shell/` files in order (`paths` -> `exports` -> `aliases` -> `functions`), then optional integrations such as `nvm` and `zoxide`.

- **Aliases**: Git shortcuts (`gs`, `gc`, `gps`), navigation (`...`, `....`), and utility shorthands. `ll` uses `eza` when installed and falls back to `ls`.
- **Functions**:
    - `cppc`: compile C++11 source files.
    - `gacp`: git add, commit, and push in one go.
    - `deepfind`: recursive grep over a path.
    - `pbcopy` / `pbpaste`: clipboard shims backed by `xclip`/`xsel` on Linux.
- **Environment**: sets up `GOPATH`, `GOPROXY`, and related exports.

### Secrets management

The project uses `secrets.sh` (copied from `config.example.sh`) to manage sensitive data. Define values such as:

- Git user name and email
- API keys
- Personal IDs

`secrets.sh` is git-ignored and loaded automatically by `common_init_funcs.sh` when present.

### Portability

All scripts honor `DOTFILES_ROOT` (default `$HOME/github/my_dot_files`). Override it in your `~/.bashrc` before sourcing `my_shell_config.sh` if you check the repo out elsewhere. zsh-only constructs are guarded so bash can source everything cleanly.

## Troubleshooting

### `secrets.sh` not found

If you see warnings about missing secrets, ensure you have copied `config.example.sh` to `secrets.sh` and populated it with your values.

### Path issues

If commands are not found, check that `DOTFILES_ROOT` is correctly set. By default it points to `$HOME/github/my_dot_files`. You can override it in your `~/.bashrc` before sourcing `my_shell_config.sh`.

## Tutorials

* [程序员内功系列--序篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)
* [程序员内功系列--iTerm与Zsh篇](https://xiaozhou.net/learn-the-command-line-iterm-and-zsh-2017-06-23.html)
* [程序员内功系列--Tmux篇](https://xiaozhou.net/learn-the-command-line-tmux-2018-04-27.html)
* [程序员内功系列–-Vim篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)
* [程序员内功系列–-常用命令行工具篇](https://xiaozhou.net/learn-the-command-line-tools-md-2018-10-11.html)
