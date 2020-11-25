#!bin/zsh

#=============== config github repos ============================================
initAlias() {
#=============== Git Setting =============================================
# git command alias
alias gs="git status"
alias ga='git add'
alias gd='git diff'
alias gf='git fetch'
alias grv='git remote -v'
alias grb='git rebase'
alias gbr='git branch'
alias gpl="git pull"
alias gps="git push"
alias gco="git checkout"
alias gl="git log"
alias gc="git commit -m"
alias grst="git reset"


#=============== Common Alias Setting =============================================
alias ll='ls -al -G'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rm -rf"
alias df="df -h"
alias mv="mv -i"
alias slink="link -s"
alias sed="sed -E"
alias l="ls -l"
alias la="ls -lhAF"
alias cd..="cd .."
alias cd...="cd ../.."
alias cd....="cd ../../.."
alias ...="cd ../.."
alias ....="cd ../../.."
alias rd="rm -rf"
}


#=============== Common Function Setting =============================================
# report error and stop running commands below 
fail_report() {
  if [[ $? -ne 0 ]]; then
    echo "error!"
    exit
  fi
}


#=============== config github repos ============================================
configMyGithubRepos() {
	git config user.email "fycjmingxing@126.com"
	git config user.name "igoingdown"
}


#=============== install go1.4 ==========================================
installGo4() {
	mkdir -p ~/local/go1.4
	cd ~/local/go1.4
	wget https://dl.google.com/go/go1.4-bootstrap-20171003.tar.gz
	tar -zxf go1.4-bootstrap-20171003.tar.gz
	cd go/src
	export CGO_ENABLED=0
	./make.bash
}


#=============== install go1.13 =========================================
installGo13(){
	mkdir -p ~/local/go1.13
	cd ~/local/go1.13
	#wget https://dl.google.com/go/$1
	tar -zxf $1
	cd go/src
	export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go
	./all.bash
}


#=============== install go  =========================================
installGo() {
	installGo4
	installGo13 $1
}


#=============== install zsh =========================================
installZsh() {
	sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	which zsh
	chsh -s /usr/bin/zsh
	echo $SHELL
}


#=============== Install dlv ============================================
installDlv() {
	go get -u github.com/go-delve/delve/cmd/dlv
}


#=============== install protobuffer 2.6.1  =========================================
installPB() {
	mkdir -p ~/github/
	cd ~/github/
	wget https://github.com/google/protobuf/releases/download/v2.6.1/protobuf-2.6.1.tar.gz
	tar -zxvf protobuf-2.6.1.tar.gz 
	# 不确定下面这句要不要，开发环境如果是旧的话，这些基本都有，如果是全新的，最好加上
	# sudo apt-get install build-essential # 不装会报错
	cd protobuf-2.6.1/ 
	./configure 
	make 
	make check 
	sudo make install
}

#=============== proxy setting  =============================================
# 现在基本不需要设置proxy了，公司的网络都可以自动跳转proxy
pon() {
	export http_proxy=10.110.216.52:3128
	export https_proxy="http://10.110.216.52:3128"
}
poff() {
	unset http_proxy
	unset https_proxy
}

