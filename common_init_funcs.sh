#bin/zsh


#=============== CPP Setting =============================================
# compile cpp program with c++11
cppc() {
	g++ -std=c++11 $1
}


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
# after status and diff, push it through
push_through(){
	gs
    fail_report
    git add .
    fail_report
    git commit -m $1
    fail_report
    gps
}


#=============== proxy setting  =============================================
export http_proxy=10.110.216.52:3128
export https_proxy="http://10.110.216.52:3128" 


#=============== Common Alias Setting =============================================
alias ll='ls -al -G'
alias zconf='vim $HOME/github/mydotfiles/my_shell_config.sh'
alias zload='source ~/.zshrc'
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


#=============== Common Function Setting =============================================
# find specified pattern under particular path recursively 
deepfind() {
	grep -r $1 $2
}
# find command line history
fh() {
	history | grep $1
}
# report error and stop running commands below 
fail_report() {
  if [[ $? -ne 0 ]]; then
    echo "error!"
    exit
  fi
}


#=============== clone my github repos ============================================
cloneMyGithubRepos() {
	mkdir -p $HOME/github/
	cd $HOME/github
	git clone git@github.com:igoingdown/mydotfiles.git
	git clone git@github.com:igoingdown/leetcode.git
	git clone git@github.com:igoingdown/python_demo_and_tool.git
	git clone git@github.com:igoingdown/hexo-posts.git
	git clone git@github.com:igoingdown/MyResume.git
}


#=============== config github repos ============================================
configMyGithubRepos() {
	git config user.email "fycjmingxing@126.com"
	git config user.name "igoingdown"
}


#=============== tmux, zsh, bash and vim config ============================================
dragConfFromGithub() {
	cd $HOME/github/mydotfiles
	cp .vimrc ~/
	cp .zshrc ~/
	cp .tmux.conf ~/
	cp .bashrc ~/
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


#=============== install go1.12 =========================================
installGo12(){
	mkdir -p ~/local/go1.12 
	cd ~/local/go1.12
	wget https://dl.google.com/go/$1
	tar -zxf $1
	cd go/src
	export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go
	./all.bash
}


#=============== install go  =========================================
installGo() {
	installGo4
	installGo12 $1
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
	source my_shell_config.sh
	go get -u github.com/go-delve/delve/cmd/dlv
}


#=============== install cool projects =========================================
# install some cool projects that I should learn through
installCoolProjects() {
	go get -d k8s.io/kubernetes
	cd $GOPATH/src/k8s.io/kubernetes
	make
}

#=============== install ycm  =========================================
# TODO: ycm should be installed at the end. or the vim will down!
installYCM() {

	cd ~/.vim/bundle/YouCompleteMe
	go get golang.org/x/xerrors
	./install.py --all
}


#=============== install redis =========================================
installRedis() {
	wget http://download.redis.io/releases/redis-5.0.5.tar.gz
	tar xzf redis-5.0.5.tar.gz
	cd redis-5.0.5
	make
}
