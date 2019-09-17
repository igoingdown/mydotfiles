#/bin/bash


#=============== generate ssh key and upload it to github ===========================================
ssh-keygen
# TODO: upload public key to github or use http first


#=============== install brew ===========================================
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"


#=============== install wget ===========================================
brew install wget


#=============== install zsh  ===========================================
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
which zsh
chsh -s /bin/zsh
echo $SHELL


#=============== install vundle  ========================================
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim


#=============== Install tmux on mac ====================================
brew install tmux


#=============== tmux, zsh, bash and vim config ============================================
mkdir -p $HOME/github/
cd $HOME/github
git clone https://github.com/igoingdown/mydotfiles.git
cd mydotfiles
cp .vimrc ~/
cp .zshrc ~/
cp .tmux.conf ~/
cp .bashrc ~/


#=============== Install nmap ====================================
brew install nmap 


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
tar -zxf go1.12.7.linux-amd64.tar.gz
cd go/src
./all.bash


#=============== install cool projects =========================================
# install some cool projects that I should learn through
go get -d k8s.io/kubernetes
cd $GOPATH/src/k8s.io/kubernetes
make


#=============== Install dlv ============================================
brew install dlv
