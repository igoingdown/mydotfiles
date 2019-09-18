#/bin/bash

source common_init_funcs.sh


#=============== generate ssh key and upload it to github ===========================================
ssh-keygen
# TODO: upload public key to github or use http first


#=============== install brew ===========================================
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"


#=============== install wget ===========================================
brew install wget


#=============== install zsh  ===========================================
installZsh


#=============== install vundle  ========================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


#=============== Install tmux ====================================
brew install tmux


#=============== config tmux, vim, zsh and bash ====================================
dragConfFromGithub


#=============== Install nmap ====================================
brew install nmap 


#=============== install golang =========================================
installGo go1.12.9.darwin-amd64.tar.gz



#=============== Install dlv ============================================
installDlv


#=============== install cool projects =========================================
# install some cool projects that I should learn through
installCoolProjects


#=============== install YCM  =========================================
installYCM
