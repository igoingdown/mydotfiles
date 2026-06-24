#!/bin/bash

# my_shell_config.sh - Shell configuration entry point.
#
# Source this from your interactive shell rc file, e.g. in ~/.bashrc:
#   source "$HOME/github/my_dot_files/my_shell_config.sh"

# Configuration: root of the dotfiles repo.
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}

# 1. Load common init functions (which in turn sources secrets.sh).
source "${DOTFILES_ROOT}/common_init_funcs.sh"

# 2. Load shell modules.
# Order matters: paths -> exports -> aliases -> functions
if [ -d "${DOTFILES_ROOT}/shell" ]; then
    source "${DOTFILES_ROOT}/shell/paths.sh"
    source "${DOTFILES_ROOT}/shell/exports.sh"
    source "${DOTFILES_ROOT}/shell/aliases.sh"
    source "${DOTFILES_ROOT}/shell/functions.sh"
else
    echo "Error: shell directory not found in ${DOTFILES_ROOT}"
fi

# 3. Load NVM (load_nvm is defined in shell/functions.sh).
load_nvm

# 4. Initialize zoxide (smart cd) as `j`, only if zoxide is installed.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd j)"
fi
