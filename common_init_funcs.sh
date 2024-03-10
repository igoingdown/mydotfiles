#!/bin/bash


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
alias gpom="git pull origin master"
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
	# 手动下载并移动至该目录更快
	wget https://dl.google.com/go/go1.4-bootstrap-20171003.tar.gz
	tar -zxf go1.4-bootstrap-20171003.tar.gz
	cd go/src
	export CGO_ENABLED=0
	./make.bash
}


#=============== install go in specific version  =========================================
installGoxx(){
    destPath=$HOME/local/go1.13
    if [ ! -d "$destPath"]; then
        echo "$destPath 不存在"
        mkdir -p "$destPath"
        cd $destPath
	    git clone git@github.com:golang/go.git
    else
        echo "$destPath 已存在"
        cd $destPath
        git pull
    fi
	cd go/src
    echo "目标 go 版本：\"$1\""
	gco go$1
	export GOROOT_BOOTSTRAP=$HOME/local/go1.4/go
	./all.bash
}


#=============== install go  =========================================
installGo() {
	installGo4
	installGoxx
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
	sudo cp src/redis-cli /usr/local/bin/
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


#=============== 检测文件和目录是否存在 =========================================
existD() {
    if [ ! -d "$1" ]; then
        echo "$1 not exist"
    else
        echo "$1 OK"
    fi

}

existF() {
    if [ ! -f "$1" ]; then
        echo "$1 not exist"
    else
        echo "$1 OK"
    fi
}


#================== 为 sed 命令转义 ==========================
expr_for_sed() {
    new_expr=$(echo $1 | gsed 's/\//\\\//g')
    echo $new_expr
}


#================== 利用 sed 命令实现递归关键词搜索并替换 ==========================
k_repalce() {
    search_keyword=$1
    origin_keyword=$2
    new_keyword=$3
    dest_dir=$4
    origin_expr=$(expr_for_sed $origin_keyword)
    new_expr=$(expr_for_sed $new_keyword)
    echo $new_expr $origin_expr
    grep -Rl --exclude-dir=kitex_gen "$search_keyword" $dest_dir | xargs gsed -i "s#$origin_expr#$new_expr#g"
}


#================== 为 sed 命令转义 ==========================
battery() {
    design_capacity=$(ioreg -rn AppleSmartBattery | grep -i DesignCapacity | tail -1 |awk -F= '{print $2 }'| sed 's/ //g')
    max_capacity=$(ioreg -rn AppleSmartBattery | grep -i MaxCapacity | tail -1| awk -F= '{print $2 }'| sed 's/ //g')
    echo $max_capacity / $design_capacity 
    awk -v a="$design_capacity" -v b="$max_capacity" 'BEGIN { print b/a }'
}


#================== 非交互式使用 kinit ==========================
alias knp='kinit --password-file=$HOME/password/kinit.txt zhaomingxing.93@BYTEDANCE.COM'


#================== 安装 rust ==========================
install_rust() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
}

