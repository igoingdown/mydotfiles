#!/bin/bash
#
# init_ubuntu.sh - Linux (Ubuntu/Debian) bootstrap script.
#
# IMPORTANT: This script is RUN MANUALLY and is never auto-executed.
#   Run it yourself with:  ./init_ubuntu.sh
#
# What it does:
#   - Installs software (CLI tools, Go). bash is the primary shell; zsh is NOT installed.
#   - Symlinks ~/.bashrc to the repo's .bashrc (stock Ubuntu base + dotfiles entry),
#     backing up any existing real ~/.bashrc first.
#   - Symlinks .vimrc / .tmux.conf when they are absent, leaving existing files untouched.
#
# Primary shell is bash.

#=============== load common init functions ===========================================
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source "${DOTFILES_ROOT}/common_init_funcs.sh"


#=============== ensure Linuxbrew is on PATH ===========================================
if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi


#=============== install CLI tools (brew preferred) ===================================
# bash is the primary shell here; zsh is intentionally NOT installed.
if command -v brew >/dev/null 2>&1; then
    for tool in eza zoxide fzf ripgrep the_silver_searcher; do
        echo "brew install ${tool}"
        brew install "${tool}" || echo "warning: failed to install ${tool}, continuing..."
    done
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y fzf ripgrep silversearcher-ag xclip
    echo "Note: eza and zoxide may need manual install on this system."
else
    echo "No brew or apt-get found. Please install CLI tools manually:"
    echo "  eza zoxide fzf ripgrep the_silver_searcher (ag) xclip"
fi


#=============== install Vundle (vim plugin manager, needed by .vimrc) =================
if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim" \
        && echo "Vundle installed (run :PluginInstall in vim to fetch plugins)"
else
    echo "Vundle already installed"
fi


#=============== OPTIONAL manual installs (commented out — uncomment if you need them) =
# These are NOT run automatically. The functions are defined in common_init_funcs.sh.
#   installGo             # Go toolchain — this box already has Go (brew). Uncomment on a fresh box.
#   installSilverSearch   # the_silver_searcher (ag) — this box already has ag + rg
#   installDlv            # Delve, the Go debugger — uncomment if you debug Go here


#=============== link ~/.bashrc to the repo (full Ubuntu base + dotfiles entry) =======
# The repo .bashrc is the stock Ubuntu .bashrc plus the dotfiles entry at the end,
# so it is a safe superset. If ~/.bashrc is already the correct symlink, skip; if it
# is a real file (e.g. the stock one), back it up once and then symlink.
bashrc_target="${DOTFILES_ROOT}/.bashrc"
if [ "$(readlink "$HOME/.bashrc" 2>/dev/null)" = "$bashrc_target" ]; then
    echo "ok .bashrc (already linked)"
else
    if [ -e "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$$" && echo "backed up existing ~/.bashrc -> ~/.bashrc.bak.$$"
    fi
    ln -sfn "$bashrc_target" "$HOME/.bashrc" && echo "linked .bashrc -> $bashrc_target"
fi


#=============== link other dotfiles only when absent =================================
# For each dotfile: if it's already the correct symlink into this repo, skip;
# if a real file or a different/broken link is already there, leave it untouched
# (never overwrite your existing config); only create the link when nothing exists.
for f in .vimrc .tmux.conf; do
    target="${DOTFILES_ROOT}/$f"
    link="$HOME/$f"
    if [ "$(readlink "$link" 2>/dev/null)" = "$target" ]; then
        echo "ok $f (already linked)"
    elif [ -e "$link" ] || [ -L "$link" ]; then
        echo "skip $f (already exists, not overwriting)"
    else
        ln -s "$target" "$link" && echo "linked $f -> $target"
    fi
done
