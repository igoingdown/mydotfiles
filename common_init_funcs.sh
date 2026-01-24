#!/bin/bash

export DOTFILES_ROOT=$HOME/github/my_dot_files

# Load secrets if available
if [ -f "${DOTFILES_ROOT}/secrets.sh" ]; then
    source "${DOTFILES_ROOT}/secrets.sh"
else
    # Fallback/Placeholder
    echo "Error: secrets.sh not found"
    exit 1
fi


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
alias gplom="git pull origin master"
alias gps="git push"
alias gco="git checkout"
alias gl="git log"
alias gc="git commit -m"
# after status and diff, push it through
push_through(){
    if [ -z "$1" ]; then
        echo "Usage: push_through <commit_message>"
        return 1
    fi
	gs
    fail_report
    git add .
    fail_report
    git commit -m "$1"
    fail_report
    gps
}


#=============== Common Alias Setting =============================================
alias ll='ls -al -G'
alias zconf='vim ${DOTFILES_ROOT}/my_shell_config.sh'
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
	git config user.email "${GITHUB_USER_EMAIL}"
	git config user.name "${GITHUB_USER_NAME}"
}


#=============== tmux, zsh, bash and vim config ============================================
dragConfFromGithub() {
	cd ${DOTFILES_ROOT}
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


#=============== install zsh =========================================
installZsh() {
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        echo "错误: 需要wget或curl安装oh-my-zsh"
        return 1
    fi
    
    if command -v curl >/dev/null 2>&1; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
    
    if command -v zsh >/dev/null 2>&1; then
        which zsh
        if chsh -s "$(which zsh)" >/dev/null 2>&1; then
            echo "成功切换到zsh: $(which zsh)"
        else
            echo "警告: 无法切换默认shell，可能需要手动运行: chsh -s $(which zsh)"
        fi
    else
        echo "错误: zsh安装失败"
        return 1
    fi
}


#=============== Install Spaceship Prompt =======================================
installSpaceship() {
    local ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
    if [ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]; then
        echo "Installing Spaceship prompt..."
        git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
        ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
    else
        echo "Updating Spaceship prompt..."
        if [ -d "$ZSH_CUSTOM/themes/spaceship-prompt/.git" ]; then
            cd "$ZSH_CUSTOM/themes/spaceship-prompt" && git pull
        else
            echo "Spaceship directory exists but is not a git repo. Skipping update."
        fi
    fi
}


#=============== Install dlv ============================================
installDlv() {
	source my_shell_config.sh
	go get -u github.com/go-delve/delve/cmd/dlv
}


#=============== install protobuffer 2.6.1  =========================================
installPB() {
	mkdir -p ~/github/
	cd ~/github/
	wget https://github.com/google/protobuf/releases/download/v2.6.1/protobuf-2.6.1.tar.gz
	tar -zxvf protobuf-2.6.1.tar.gz 
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
    local sed_cmd
    if command -v gsed >/dev/null 2>&1; then
        sed_cmd="gsed"
    else
        sed_cmd="sed"
    fi
    new_expr=$(echo "$1" | $sed_cmd 's/\//\\\//g')
    echo "$new_expr"
}


#================== 利用 sed 命令实现递归关键词搜索并替换 ==========================
k_replace() {
    if [ $# -ne 4 ]; then
        echo "用法: k_replace <搜索关键词> <原关键词> <新关键词> <目标目录>"
        return 1
    fi
    
    local search_keyword=$1
    local origin_keyword=$2
    local new_keyword=$3
    local dest_dir=$4
    
    local sed_cmd
    if command -v gsed >/dev/null 2>&1; then
        sed_cmd="gsed"
    else
        sed_cmd="sed"
    fi
    
    local origin_expr=$(expr_for_sed "$origin_keyword")
    local new_expr=$(expr_for_sed "$new_keyword")
    
    echo "替换: $origin_expr -> $new_expr"
    
    if [ ! -d "$dest_dir" ]; then
        echo "错误: 目录 $dest_dir 不存在"
        return 1
    fi
    
    grep -Rl --exclude-dir=kitex_gen "$search_keyword" "$dest_dir" | xargs $sed_cmd -i "s#$origin_expr#$new_expr#g"
}


#================== 为 sed 命令转义 ==========================
battery() {
    design_capacity=$(ioreg -rn AppleSmartBattery | grep -i DesignCapacity | tail -1 |awk -F= '{print $2 }'| sed 's/ //g')
    max_capacity=$(ioreg -rn AppleSmartBattery | grep -i MaxCapacity | tail -1| awk -F= '{print $2 }'| sed 's/ //g')
    echo $max_capacity / $design_capacity 
    awk -v a="$design_capacity" -v b="$max_capacity" 'BEGIN { print b/a }'
}


#================== 安全kinit认证 ==========================
knp() {
    if [ -f "$HOME/.kinit_pass" ]; then
        kinit --password-file="$HOME/.kinit_pass" "${KINIT_USER}"

    else
        echo "请创建 ~/.kinit_pass 文件或使用 kinit 手动认证"
        kinit "${KINIT_USER}"
    fi
}


#================== 安装 rust ==========================
install_rust() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
}

