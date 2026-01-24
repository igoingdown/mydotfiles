#!/bin/bash

# Source common functions
# Ensure DOTFILES_ROOT is set if not already
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/common_init_funcs.sh

echo "Starting macOS initialization..."

#=============== install brew ===========================================
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add brew to PATH for immediate use (M1/M2/M3 vs Intel)
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed."
fi

#=============== install dependencies via Brewfile ===========================================
echo "Installing dependencies from Brewfile..."
brew bundle --file=${DOTFILES_ROOT}/Brewfile || echo "Brew bundle finished with some warnings/errors."


#=============== install zsh & oh-my-zsh ===========================================
installZsh


#=============== install vundle ========================================
if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
    echo "Installing Vundle..."
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
else
    echo "Vundle already installed."
fi


#=============== config tmux, vim, zsh and bash ====================================
echo "Linking configuration files..."
dragConfFromGithub


#=============== Install Spaceship Prompt =======================================
installSpaceship


#=============== Post-Install Checks ===========================================
echo "Initialization complete!"
echo "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
