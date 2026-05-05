#!/bin/bash

# Configuration
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}

# 1. Load Common Functions & Secrets
# common_init_funcs.sh sources secrets.sh
source ${DOTFILES_ROOT}/common_init_funcs.sh

# 2. Load Shell Modules
# Order matters: paths -> exports -> aliases -> functions
if [ -d "${DOTFILES_ROOT}/shell" ]; then
    source ${DOTFILES_ROOT}/shell/paths.sh
    source ${DOTFILES_ROOT}/shell/exports.sh
    source ${DOTFILES_ROOT}/shell/aliases.sh
    source ${DOTFILES_ROOT}/shell/functions.sh
else
    echo "Error: shell directory not found in ${DOTFILES_ROOT}"
fi

# 3. Load Additional Configs
if [ -f "${DOTFILES_ROOT}/bbs_conf.sh" ]; then
    source ${DOTFILES_ROOT}/bbs_conf.sh
fi

# Load NVM (Lazy load or direct load as per previous config)
# load_nvm is defined in shell/functions.sh
load_nvm
