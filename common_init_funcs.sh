#!/bin/bash

export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}

# Load secrets if available
if [ -f "${DOTFILES_ROOT}/secrets.sh" ]; then
    source "${DOTFILES_ROOT}/secrets.sh"
else
    # Fallback/Placeholder
    echo "Warning: secrets.sh not found at ${DOTFILES_ROOT}/secrets.sh"
    echo "Some features may not work without secrets.sh. Continuing..."
fi


#=============== clone my github repos ============================================
cloneMyGithubRepos() {
	mkdir -p $HOME/github/
	cd "$HOME/github" || return 1
	git clone git@github.com:igoingdown/leetcode.git
	git clone git@github.com:igoingdown/python_demo_and_tool.git
	git clone git@github.com:igoingdown/hexo-posts.git
	git clone git@github.com:igoingdown/MyResume.git
}


# Git identity (user.name / user.email) is intentionally NOT managed here.
# The single source of truth is the global ~/.gitconfig.


#=============== tmux, zsh, bash and vim config ============================================
dragConfFromGithub() {
	cd ${DOTFILES_ROOT}
	cp .vimrc ~/
	cp .zshrc ~/
	cp .tmux.conf ~/
	cp .bashrc ~/
}


#=============== install zsh =========================================
installZsh() {
    # (1) install zsh if missing
    if ! command -v zsh >/dev/null 2>&1; then
        echo "zsh not found, installing..."
        if command -v brew >/dev/null 2>&1; then
            brew install zsh
        else
            sudo apt-get update && sudo apt-get install -y zsh
        fi
    else
        echo "zsh already installed: $(command -v zsh)"
    fi

    if ! command -v zsh >/dev/null 2>&1; then
        echo "错误: zsh安装失败"
        return 1
    fi

    # (2) install oh-my-zsh (unattended) if not already present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        if command -v curl >/dev/null 2>&1; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        elif command -v wget >/dev/null 2>&1; then
            sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        else
            echo "错误: 需要wget或curl安装oh-my-zsh"
            return 1
        fi
    else
        echo "oh-my-zsh already installed at $HOME/.oh-my-zsh"
    fi

    # (3) try to switch default shell to zsh, guarded
    if chsh -s "$(command -v zsh)" >/dev/null 2>&1; then
        echo "成功切换到zsh: $(command -v zsh)"
    else
        echo "警告: 无法切换默认shell，可能需要手动运行: chsh -s $(command -v zsh)"
    fi
}


#=============== Install the_silver_searcher (ag) ============================================
installSilverSearch() {
    if command -v brew >/dev/null 2>&1; then
        brew install the_silver_searcher
    else
        sudo apt-get install -y silversearcher-ag
    fi
}


#=============== Install Go ============================================
installGo() {
    if command -v brew >/dev/null 2>&1; then
        brew install go
        return $?
    fi

    local arch
    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            echo "错误: 不支持的架构: $(uname -m)"
            return 1
            ;;
    esac

    local go_version
    # Resolve the latest stable Go version dynamically; fall back to a known-good one.
    if command -v curl >/dev/null 2>&1; then
        go_version=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
    elif command -v wget >/dev/null 2>&1; then
        go_version=$(wget -qO- "https://go.dev/VERSION?m=text" | head -1)
    fi
    case "$go_version" in
        go*) ;;                         # looks like "go1.26.2"
        *) go_version="go1.23.4" ;;     # fallback if the lookup failed
    esac
    local tarball="${go_version}.linux-${arch}.tar.gz"
    local url="https://go.dev/dl/${tarball}"

    cd "$HOME" || return 1
    if command -v curl >/dev/null 2>&1; then
        curl -fsSLO "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget "$url"
    else
        echo "错误: 需要wget或curl下载go"
        return 1
    fi

    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$tarball"
    echo "Go installed to /usr/local/go. Make sure /usr/local/go/bin is on your PATH."
}


#=============== Install dlv ============================================
installDlv() {
	go install github.com/go-delve/delve/cmd/dlv@latest
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

    grep -Rl "$search_keyword" "$dest_dir" | xargs $sed_cmd -i "s#$origin_expr#$new_expr#g"
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
