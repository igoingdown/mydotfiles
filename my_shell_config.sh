#bin/zsh

#=============== MySQL Setting =============================================
export MYSQLPATH=/usr/local/mysql
export PATH=$PATH:$MYSQLPATH/bin
export PATH="/usr/local/opt/mysql-client/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig"
export CPPFLAGS="-I/usr/local/opt/mysql-client/include"
#Temp setting
export LDFLAGS=""
#Correct setting
#export LDFLAGS="-L/usr/local/opt/mysql-client/lib"


#=============== Golang Setting =============================================
export GOPATH=$HOME/golang
export GOROOT=/usr/local/go
export GO111MODULE=on
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin
# build go project 
alias build="go build ."


#=============== ETCD Setting =============================================
export ETCDCTL_API=3


#=============== Dev machine Setting =============================================
# virtualdev machine ssh login
alias dev="ssh root@10.233.153.40"
# copy local files to dev machine
dscp() {
	scp $1 root@10.233.153.40:~/
}
# copy file on dev machine to local desktop
cpb() {
	scp root@10.233.153.40:~/$1 ~/Desktop
}


#=============== EntryTask Setting =============================================
# entry task env
export ENV=dev
# entry task docker image 
export APIIMAGE=entry-zhaomingxing-api
export TCPIMAGE=entry-zhaomingxing-tcp


#=============== ERU Setting =============================================
export ERU=10.22.12.87:5001
# support list and log operation on container level
container() {
	cli --eru $ERU container $1 $2 
}
# stop a eru container and delete it.
stop_and_remove() {
	cli --eru $ERU container stop $1
	fail_report
	cli --eru $ERU container remove $1
}


#=============== RDS Setting ===========================================
alias entry_bus="cd ~/golang/src/git.garena.com/mingxing.zhao"
alias zb="cd ~/golang/src/git.garena.com/shopee/cloud/"
alias magy="cd ~/golang/src/git.garena.com/magy/"
alias mt="cd ~/golang/src/self_test/"
rds() {
	cli --eru $ERU container list rdsmingxing
	cli --eru $ERU container list rdswebui 
}


#=============== Redis Setting =============================================
# start local redis server
alias redis="redis-server /usr/local/etc/redis.conf"


#=============== CPP Setting =============================================
# compile cpp program with c++11
cppc() {
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
# execute bash scripts in a new terminal 
tm() {
	open -a Terminal.app $1
}
# open markdown file with typora 
tpr() {
	open -a /Applications/Typora.app $1
}


#=============== Common Alias Setting =============================================
alias ll='ls -al -G'
alias zconf='vim ~/my_shell_config.sh'
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



#=============== Order Meal Setting =============================================
od() {
	curl 
		-d '{"food_id": 6}' 
		-H "Content-Type: application/json"\
		-H 'Authorization: 104089c162aeffd9b03744adbe5a95be21a56237'\
		-X POST http://api/order/2
}

