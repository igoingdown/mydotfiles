#/bin/bash


#=============== load common funcs ===========================================
source common_init_funcs.sh
# TODO: update source list


#=============== generate ssh key and upload it to github ===========================================
ssh-keygen
# TODO: upload public key to github, gitlab and so on or use http first


#=============== install zsh  ===========================================
installZsh


#=============== install vim  ===========================================
sudo apt-get install vim
vim --version


#=============== install vundle  ========================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


#=============== install tmux =================================
sudo apt-get install tmux


#=============== tmux, zsh, bash and vim config ============================================
dragConfFromGithub


#=============== install nmap =================================
sudo apt-get install nmap 


#=============== install gcc and cmake  ============================================
sudo apt update
sudo apt install build-essential
sudo apt-get install manpages-dev
sudo apt-get install cmake


#=============== install golang =========================================
installGo


#=============== install cool projects =========================================
# install some cool projects that I should learn through
go get -d k8s.io/kubernetes
cd $GOPATH/src/k8s.io/kubernetes
make


#=============== Install GDB ============================================
sudo apt-get update
sudo apt-get install gdb


#=============== Install dlv ============================================
installDlv


#=============== install PB =========================================
installPB
