#/bin/bash

echo #=============== install zsh  =============================================
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
source ~/.zshrc
zsh --version
which zsh
chsh -s /usr/bin/zsh
echo $SHELL

echo #=============== install vim  =============================================
sudo apt-get install vim
vim --version

echo #=============== install vundle  =============================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


echo #=============== install tmux on ubuntu =============================================
sudo apt-get install tmux

echo #=============== Install tmux on mac =============================================
brew install tmux

echo #=============== tmux config =============================================
cd 
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf


echo #=============== install tmux on ubuntu =============================================
sudo apt-get install nmap 

echo #=============== Install tmux on mac =============================================
brew install nmap 



echo #=============== install gcc =============================================
sudo apt update
sudo apt install build-essential
sudo apt-get install manpages-dev


echo #=============== install golang =============================================
apt-get purge golang-go
mkdir -p ~/local/go1.4
mkdir -p ~/local/go1.12 

echo #=============== install go1.4 =============================================
cd ~/local/go1.4
git clone https://github.com/golang/go.git -b release-branch.go1.4
cd go/src
./all.bash

echo export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go > ~/.bashrc
source ~/.bashrc

echo #=============== install go1.12 =============================================
cd ~/local/go1.12
wget https://storage.googleapis.com/golang/go1.12.7.linux-amd64.tar.gz
tar zxvf go1.12.7.linux-amd64.tar.gz
cd go/src
./all.bash

echo #=============== Golang Setting ============================================= > ~/.bashrc
echo export GOROOT=$HOME/local/go1.12/go > ~/.bashrc
echo export PATH=$PATH:$GOROOT/bin > ~/.bashrc
echo export GOPATH=$HOME/go > ~/.bashrc
echo export PATH=$PATH:$GOPATH/bin > ~/.bashrc
echo export GO111MODULE=on > ~/.bashrc
source ~/.bashrc

echo #=============== Install GDB =============================================
sudo apt-get update
sudo apt-get install gdb
