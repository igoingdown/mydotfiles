#!/bin/bash

#=============== load common funcs =============================================
source $HOME/github/my_dot_files/common_init_funcs.sh


#=============== Base PATH Setting =============================================
export PATH=$HOME/.autojump/bin:/usr/local/bin:/usr/bin:/bin:/usr/games
export PATH=$PATH:/usr/sbin:/sbin:/opt/puppetlabs/bin:/usr/local/munki
export PATH=$PATH:~/bin
# 加入 latex 工具集命令
export PATH=$PATH:/usr/local/texlive/2020/bin/x86_64-darwin
# 加入开发机的常用 bin
export PATH=$PATH:/opt/tiger/ss_bin:/opt/tiger/ss_lib/bin:/opt/tiger/yarn_deploy/hadoop/bin
# 加入 maven 的 bin
export PATH=$PATH:$HOME/apache-maven-3.8.4/bin
# 加入 homebrew 的 bin
export PATH=$PATH:/opt/homebrew/bin
# 加入 rust 的 bin
export PATH=$PATH:$HOME/.cargo/bin
# 加入 gnu 的 bin
export PATH=/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH
# 加入 python 脚本 bin
export PATH=$HOME/golang/src/code.byted.org/wenqing.88/python_tools/tools:$PATH


#=============== MySQL Setting =============================================
export MYSQLPATH=/usr/local/mysql
export PATH=$PATH:$MYSQLPATH/bin
export PATH=$PATH:/usr/local/opt/mysql-client/bin
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig"
export CPPFLAGS="-I/usr/local/opt/mysql-client/include"
export LDFLAGS="-L/usr/local/opt/mysql-client/lib"


#=============== Golang Setting =============================================
export GOPATH=$HOME/golang
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOPATH/bin/darwin_amd64
export PATH=/opt/homebrew/opt/go@1.21/bin:$PATH
export GOPROXY="https://go-mod-proxy.byted.org,https://goproxy.cn,https://proxy.golang.org,direct"
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
export GOSUMDB="sum.golang.google.cn"
export GOOS="darwin"
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
DEV_IP="10.37.2.187"
NEW_DEV_IP="10.37.27.207"
# 线上开发机
ONLINE_DEV_IP="10.25.60.33"
alias odev="ssh $DEV_USER_NAME@$ONLINE_DEV_IP"
alias dev="ssh $DEV_USER_NAME@$DEV_IP"
alias ndev="ssh $DEV_USER_NAME@$NEW_DEV_IP"
# copy local files to dev machine
dscp() {
	scp -r $1 $DEV_USER_NAME@$DEV_IP:~/
}
# copy file on dev machine to local
cpb() {
	scp -r $DEV_USER_NAME@$DEV_IP:~/$1 ~/
}
# copy file on dev machine to local with specified destination
cpbd() {
	scp -r $DEV_USER_NAME@$DEV_IP:~/$1 $2 
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
alias dots="cd $HOME/github/my_dot_files"
alias lc="cd $HOME/github/leetcode"
alias resume="cd $HOME/github/MyResume"
alias posts="cd $HOME/github/myblog/blog"


#=============== Git Setting =============================================
# git command alias
alias gs="git status"
alias gs.="git status ."
alias ga='git add'
alias ga.='git add .'
alias gd='git --no-pager diff --word-diff'
alias gd.='git diff .'
alias gf='git fetch'
alias grv='git remote -v'
alias grb='git rebase'
alias grst='git reset'
alias gmd='git commit --amend'
alias gbr='git branch'
alias gpl="git pull"
alias gps="git push"
alias gco="git checkout"
alias gcz="git checkout zmx_dev"
alias gl="git log --oneline --graph --decorate --all"
alias gc="git commit -m"
alias gac="ga . & gc"
alias st="git stash"
alias sta="git stash apply"
alias stp="git stash pop"
alias grhom="git reset --hard origin/master"
alias grmb="git branch | grep -v master | xargs git branch -D "
# after status and diff, push it through
gacp(){
	gs
    fail_report
    git add .
    fail_report
    git commit -m $1
    fail_report
    gps origin $2
}

gdtf(){
	gs
    fail_report
    git add $1
    fail_report
    git commit -m "test"
    fail_report
    gps origin master
    fail_report
    mv $2 $1
    fail_report
    git add $1
    git commit -m "test"
    fail_report
    gps origin master
    fail_report
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
    echo "ok"
	#export http_proxy=10.110.216.52:3128
	#export https_proxy="http://10.110.216.52:3128"
}
poff() {
    echo "ok"
	#unset http_proxy
	#unset https_proxy
}

proxy() {
    export http_proxy=10.20.47.147:3128
    export https_proxy=10.20.47.147:3128
    export no_proxy=*.byted.org
    echo "proxy: on"
}

noproxy() {
    unset http_proxy
    unset https_proxy
    echo "proxy: off"
}


#=============== Common Alias Setting =============================================
alias ll='exa -al'
alias zconf='vim $HOME/github/my_dot_files/my_shell_config.sh'
alias zload='source ~/.zshrc'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rm -rf"
alias df="df -h"
alias mv="mv -f"
alias slink="link -s"
alias sed="sed -E"
alias l="ls -l"
alias la="ls -lhAF"
alias cd..="cd .."
alias cd...="cd ../.."
alias cd....="cd ../../.."
alias ...="cd ../.."
alias ....="cd ../../.."
alias did="echo -n 4063392393857421 | tee >(pbcopy)"
alias uid="echo -n 2783600558227156 | tee >(pbcopy)"
alias eid="echo -n 8152681 | tee >(pbcopy)"
alias alarmid="echo -n 6796652467007258628 | tee >(pbcopy)"
alias fcid="echo -n 6214830155051807 | tee >(pbcopy)"
alias pnum="echo -n 18810860130 | tee >(pbcopy)"

alias gkb="ginkgo bootstrap"
alias gkg="ginkgo generate"
alias gink="gkb && gkg"
alias aga='apply-git-acl'


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

# 文件生成
# 参数表示文件和长度
pwfgen() {
    pwgen -H $1 -Bncyv $2 1 | pbcopy
}

#=============== protobuffer version Setting =============================================
# need install protobuffer 2.6.1 first
export LD_LIBRARY_PATH=/usr/local/lib


#=============== idl Setting =============================================
alias li="ln -s $GOPATH/src/code.byted.org/cpputil/service_rpc_idl idl"
alias ldi="ln -s ~/repos/data/idl data_idl"


#=============== kitool Setting =============================================
alias kv="kitool -v"


#=============== python setting =============================================
alias python="/usr/bin/python "
export PYTHONPATH=$PYTHONPATH:"~/repos/toutiao/app:~/repos/toutiao/lib:/~/repos/toutiao/lib/python_package/lib/python2.7/site-packages:~/repos/toutiao/lib/python_package"


#=============== quick command to open software =============================================
chrome() {
   open -a 'Google Chrome' "$@"
}


#=============== quick command to common tools =============================================
stamp2time() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/timestamp.py $1
}
now_time() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/now_time.py
}
time2stamp() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/time2stamp.py $1
}


#=============== docker Setting =============================================
alias dops="docker ps -a"
alias dorm='docker rm'


#=============== ag Setting =============================================
alias ag='ag --ignore-dir thrift_gen --ignore-dir clients --ignore-dir kitex_gen --ignore-dir pb_gen --ignore-dir ugc_thecat_pyrpc'



#=============== BYR BBS Setting =============================================
source $HOME/github/my_dot_files/bbs_conf.sh


#=============== ppe shell config =============================================
jump_ppe_by_psm () {
    cat ~/psm.txt | cut -f 1 -d " " | fzf | read psm
    ~/scripts/bytedance/byteshell_ppe.sh $psm
}
alias ppe=jump_ppe_by_psm


#=============== plantuml config =============================================
export PLANTUML_LIMIT_SIZE=65536


#=============== sonic compile config =============================================
export GOARCH=arm64


#=============== sonic compile config =============================================
export CONSUL_HTTP_HOST=10.37.2.187
export CONSUL_HTTP_PORT=2280


#=============== rust config =============================================
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"


#=============== tce api config =============================================
export API_KEY=cf78b5adaacb1c37743c6a933aa99f0c


#=============== metrics api config =============================================
export METRICS_APP=ugc_devops
export METRICS_KEY=46b428e790eb4ac2b502526ef835f859


#=============== repo name extract =============================================
repo_name () {
    echo $1 | gsed 's/.*:\(.*\)\.git/\1/'
}


#=============== plantuml preview =============================================
ppv() {
    plantuml $1.puml && open $1.png
}
ppc() {
    cat $1.puml | pbcopy
}
