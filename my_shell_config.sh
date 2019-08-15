#bin/zsh

#=============== MySQL Setting =============================================
export MYSQLPATH=/usr/local/mysql
export PATH=$PATH:$MYSQLPATH/bin
export PATH="/usr/local/opt/mysql-client/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig"
export CPPFLAGS="-I/usr/local/opt/mysql-client/include"
export LDFLAGS="-L/usr/local/opt/mysql-client/lib"


#=============== Golang Setting =============================================
export GOPATH=$HOME/golang
export GOROOT=/usr/local/go
export GO111MODULE=on
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin
# build go project 
alias build="go build ."


#=============== EntryTask Setting =============================================
# entry task env
export ENV=dev
# entry task docker image 
export APIIMAGE=entry-zhaomingxing-api
export TCPIMAGE=entry-zhaomingxing-tcp


#=============== RDS Setting =============================================
alias entry_bus="cd ~/golang/src/git.garena.com/mingxing.zhao"
alias zero_bus="cd ~/golang/src/git.garena.com/shopee/cloud/"
alias magy="cd ~/golang/src/git.garena.com/magy/"
alias magy_test="cd ~/golang/src/self_test/test_backup"


#=============== Redis Setting =============================================
# start local redis server
alias redis="redis-server /usr/local/etc/redis.conf"


#=============== CPP Setting =============================================
# compile cpp program with c++11
cpc() {
	g++ -std=c++11 $1
}


#=============== LEETCODE Setting =============================================
alias leetcode="cd ~/leetcode"


#=============== Resume Setting =============================================
alias resume="cd ~/MyResume"


#=============== Hexo Setting =============================================
alias posts="cd ~/myblog/blog"
# new hexo post  
newp() {
	hexo new post $1
}
alias hd='hexo g -d'


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


#=============== Open File Setting =============================================
# open file with sublime 
sublime() {
	open -a /Applications/Sublime\ Text.app $1
}
# open file with VSC 
vsc() {
	open -a /Applications/Visual\ Studio\ Code.app $1
}
# execute shell script in a new terminal, works for MacOS 
shnt() {
	open -a Terminal.app $1
}


#=============== Common Alias Setting =============================================
alias ll='ls -al -G'
alias zconf='vim ~/.zshrc'
alias zload='source ~/.zshrc'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rmdir"
alias df="df -h"
alias mv="mv -i"
alias slink="link -s"
alias sed="sed -E"
alias l="ls -l"
alias la="ls -lhAF"
alias ll="ls -lhF"
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
