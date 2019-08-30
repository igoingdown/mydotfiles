#/bin/bash

#=============== install zsh  ===========================================
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
source ~/.zshrc
zsh --version
which zsh
chsh -s /usr/bin/zsh
echo $SHELL

#=============== install vim  ===========================================
sudo apt-get install vim
vim --version

#=============== install vundle  ========================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


#=============== install tmux on ubuntu =================================
sudo apt-get install tmux

#=============== Install tmux on mac ====================================
brew install tmux

#=============== tmux config ============================================
cd 
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf


#=============== install tmux on ubuntu =================================
sudo apt-get install nmap 

#=============== Install tmux on mac ====================================
brew install nmap 



#=============== install gcc ============================================
sudo apt update
sudo apt install build-essential
sudo apt-get install manpages-dev


#=============== install golang =========================================
apt-get purge golang-go
mkdir -p ~/local/go1.4
mkdir -p ~/local/go1.12 

#=============== install go1.4 ==========================================
cd ~/local/go1.4
git clone https://github.com/golang/go.git -b release-branch.go1.4
cd go/src
./all.bash
echo export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go > ~/.bashrc
source ~/.bashrc

#=============== install go1.12 =========================================
cd ~/local/go1.12
wget https://storage.googleapis.com/golang/go1.12.7.linux-amd64.tar.gz
tar zxvf go1.12.7.linux-amd64.tar.gz
cd go/src
./all.bash

#=============== install cool projects =========================================
# install some cool projects that I should learn through
go get -d k8s.io/kubernetes
cd $GOPATH/src/k8s.io/kubernetes
make


#=============== Golang Setting =========================================
echo export GOROOT=$HOME/local/go1.12/go > ~/.bashrc
echo export PATH=$PATH:$GOROOT/bin > ~/.bashrc
echo export GOPATH=$HOME/go > ~/.bashrc
echo export PATH=$PATH:$GOPATH/bin > ~/.bashrc
echo export GO111MODULE=on > ~/.bashrc
source ~/.bashrc

#=============== Install GDB ============================================
sudo apt-get update
sudo apt-get install gdb
