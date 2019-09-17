#/bin/bash


# TODO: update source list


#=============== generate ssh key and upload it to github ===========================================
ssh-keygen
# TODO: upload public key to github, gitlab and so on or use http first



#=============== install zsh  ===========================================
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
which zsh
chsh -s /usr/bin/zsh
echo $SHELL


#=============== install vim  ===========================================
sudo apt-get install vim
vim --version


#=============== install vundle  ========================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


#=============== install tmux =================================
sudo apt-get install tmux


#=============== tmux, zsh, bash and vim config ============================================
mkdir -p $HOME/github/
cd $HOME/github
git clone https://github.com/igoingdown/mydotfiles.git
cd mydotfiles
cp .vimrc ~/
cp .zshrc ~/
cp .tmux.conf ~/
cp .bashrc ~/


#=============== install nmap =================================
sudo apt-get install nmap 


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
wget https://dl.google.com/go/go1.4-bootstrap-20171003.tar.gz
tar -zxf go1.4-bootstrap-20171003.tar.gz
cd go/src
export CGO_ENABLED=0
./make.bash
export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go



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


#=============== Install GDB ============================================
sudo apt-get update
sudo apt-get install gdb


#=============== Install dlv ============================================
sudo apt-get install dlv
