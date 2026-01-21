# my dot files

This repository is used to manage all my dot configuration files, scripts, and development environment settings.

## 🚀 Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/igoingdown/mydotfiles.git ~/github/my_dot_files
cd ~/github/my_dot_files
```
*Note: The scripts now support dynamic paths, but keeping it in `~/github/my_dot_files` is recommended.*

### 2. Configure Secrets
Copy the example configuration file and fill in your private information (API keys, internal IPs, etc.).
```bash
cp config.example.sh secrets.sh
vim secrets.sh
```
**Important:** `secrets.sh` is git-ignored. Never commit your secrets!

### 3. Install Dependencies (macOS)
Use the initialization script to set up Homebrew, install packages, and link configurations.
```bash
./init_mac.sh
```
This script will:
* Install Homebrew (if missing)
* Install tools via `Brewfile` (git, zsh, tmux, go, eza, ripgrep, etc.)
* Configure Zsh (Oh My Zsh)
* Setup Vim (Vundle)
* Link dotfiles (`.zshrc`, `.vimrc`, etc.)

## 📂 Project Structure

```bash
├── Brewfile                # Homebrew bundle dependencies
├── README.md               # Documentation
├── bbs_conf.sh             # BBS shortcuts
├── common_init_funcs.sh    # Shared functions & config loader
├── config.example.sh       # Template for secrets & config
├── goto                    # Quick jump script
├── init_dev.sh             # Linux initialization scripts
├── init_mac.sh             # macOS initialization (Main Entry)
├── mac_mock_devbox.sh      # Mock env vars for local testing
└── my_shell_config.sh      # Main shell configuration & aliases
```

## 🛠 Requirements

* macOS (for `init_mac.sh`) or Linux
* Git
* Internet connection

All other dependencies (Zsh, Tmux, etc.) are handled automatically by `init_mac.sh` and `Brewfile`.

## 📚 Tutorials

* [程序员内功系列--序篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)
* [程序员内功系列--iTerm与Zsh篇](https://xiaozhou.net/learn-the-command-line-iterm-and-zsh-2017-06-23.html)
* [程序员内功系列--Tmux篇](https://xiaozhou.net/learn-the-command-line-tmux-2018-04-27.html)
* [程序员内功系列–-Vim篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)  
* [程序员内功系列–-常用命令行工具篇](https://xiaozhou.net/learn-the-command-line-tools-md-2018-10-11.html)
