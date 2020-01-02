#bin/zsh


#=============== Base PATH Setting =============================================
export PATH=/home/zhaomingxing.93/.autojump/bin:/usr/local/bin:/usr/bin:/bin:/usr/games:~/bin
# 加入开发机的常用bin
export PATH=$PATH:/opt/tiger/ss_bin:/opt/tiger/ss_lib/bin:/opt/tiger/yarn_deploy/hadoop/bin


#=============== MySQL Setting =============================================
export MYSQLPATH=/usr/local/mysql
export PATH=$PATH:$MYSQLPATH/bin
export PATH=$PATH:/usr/local/opt/mysql-client/bin
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig"
export CPPFLAGS="-I/usr/local/opt/mysql-client/include"
export LDFLAGS="-L/usr/local/opt/mysql-client/lib"


#=============== Golang Setting =============================================
export GOPATH=$HOME/golang
export GOROOT=$HOME/local/go1.13/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin
# build go project 
alias build="go build ."
# 开启go mod
mod_on() {
	export GO111MODULE=on
}
# 关闭go mod
mod_off() {
	export GO111MODULE=off
}


#=============== ETCD Setting =============================================
export ETCDCTL_API=3


#=============== tmux Setting =============================================
# 下面的设置并不是很好，使用下面的配置之前，应该先开启一个tmux session 然后再搞
alias tma="tmux a"
alias tx="tmux"


#=============== Dev machine Setting =============================================
# dev machine ssh login
DEV_USER_NAME="zhaomingxing.93"
DEV_IP="10.224.27.31"
# 线上开发机
ONLINE_DEV_IP="10.25.60.33"
alias odev="ssh $DEV_USER_NAME@$ONLINE_DEV_IP"
alias dev="ssh $DEV_USER_NAME@$DEV_IP"
# copy local files to dev machine
dscp() {
	scp -r $1 $DEV_USER_NAME@$DEV_IP:~/
}
# copy file on dev machine to local
cpb() {
	scp -r $DEV_USER_NAME@$DEV_IP:~/$1 ~/
}
# copy local files to online dev machine
odscp() {
	scp -r $1 $DEV_USER_NAME@$ONLINE_DEV_IP:~/
}
# copy file on online dev machine to local
ocpb() {
	scp -r $DEV_USER_NAME@$ONLINE_DEV_IP:~/$1 ~/
}



#=============== Redis Setting =============================================
# start local redis server
alias redis="redis-server /usr/local/etc/redis.conf"


#=============== CPP Setting =============================================
# compile cpp program with c++11
cppc() {
	g++ -std=c++11 $1
}


#=============== Hexo Setting =============================================
# new hexo post  
newp() {
	hexo new post $1
}
alias hd='hexo g -d'


#=============== Github repos Setting =============================================
alias gt="cd $HOME/github/"
alias dots="cd $HOME/github/mydotfiles"
alias lc="cd $HOME/github/leetcode"
alias resume="cd $HOME/github/MyResume"
alias posts="cd $HOME/github/myblog/blog"


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
alias gac="ga . & gc"
alias st="git stash"
alias sta="git stash apply"
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
# 删除当前目录下文件名符合特定pattern的文件
rm_pattern_files() {
  find -name $1 | xargs rm -rf
}
# 使用doas运行测试, 需要两个参数，分别是服务psm和需要运行的测试函数名
got() {
  doas -p $1 go test -v -run $2
}
# 在当前目录下创建特定conf的软链接
lcnf() {
  ln -s $1 conf
}


#=============== 头条开发机consul切换配置 =============================================
# 切换开发机所在的consul, 可选参数为boe,langfang和huailai
sc() {
  /opt/tiger/consul_devbox/bin/switch.sh $1
}


#=============== shengji_con Setting =============================================
alias sj="cd ~/golang/src/code.byted.org/toutiao_ugc/shengji_con_content_consume_scripts"
alias vt="cd ~/golang/src/git.byted.org/toutiao/ugc/vote"



#=============== boe Setting =============================================
#将idc设为boe,这对逃逸之后联调和线上开发机联调不好
#export RUNTIME_IDC_NAME=boe


#=============== protobuffer version Setting =============================================
# need install protobuffer 2.6.1 first
export LD_LIBRARY_PATH=/usr/local/lib


#=============== idl Setting =============================================
alias li="ln -s ~/repos/toutiao/lib/idl idl"
alias ldi="ln -s ~/repos/data/idl data_idl"



#=============== kitool Setting =============================================
alias kv="kitool -v"


#=============== go mod setting =============================================
# 在当前目录下创建特定conf的软链接
go113() {
	go env -w GOPROXY="https://go-mod-proxy.byted.org,https://goproxy.cn,https://proxy.golang.org,direct"
	go env -w GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
	go env -w GOSUMDB="sum.golang.google.cn"
}



#=============== python setting =============================================
alias python="~/repos/toutiao/runtime/bin/python"
export PYTHONPATH=$PYTHONPATH:"~/repos/toutiao/app:~/repos/toutiao/lib:/~/repos/toutiao/lib/python_package/lib/python2.7/site-packages:~/repos/toutiao/lib/python_package" 

