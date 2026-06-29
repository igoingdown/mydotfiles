#=============== Clipboard Shim =============================================
# On Linux there is no pbcopy/pbpaste. Provide portable shims backed by
# xclip or xsel; fall back to silent no-ops if neither is available.
if ! command -v pbcopy >/dev/null 2>&1; then
    if command -v xclip >/dev/null 2>&1; then
        pbcopy() {
            xclip -selection clipboard
        }
        pbpaste() {
            xclip -selection clipboard -o
        }
    elif command -v xsel >/dev/null 2>&1; then
        pbcopy() {
            xsel --clipboard --input
        }
        pbpaste() {
            xsel --clipboard --output
        }
    else
        pbcopy() {
            cat >/dev/null
        }
        pbpaste() {
            :
        }
    fi
fi

#=============== CPP Functions =============================================
# compile cpp program with c++11
cppc() {
    if [ -z "$1" ]; then
        echo "Error: Source file is required."
        return 1
    fi
    g++ -std=c++11 "$1"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to compile C++ program."
    fi
}

#=============== Hexo Functions =============================================
# new hexo post
newp() {
    if [ -z "$1" ]; then
        echo "Error: Post title is required."
        return 1
    fi
    hexo new post "$1"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create new Hexo post."
    fi
}

# hdeploy: 一键发文 + 部署博客。
#   1. 切到能构建的 Node 版本(老 Hexo 工具链在 Node 26+ 上会因 util.isDate
#      被移除而构建失败,必须用 Node 18)。
#   2. 提交并推送文章源码到博客源码仓库。
#   3. hexo clean && generate && deploy,把渲染产物部署上线。
# 用法: hdeploy ["commit 信息"]
#   - commit 信息可缺省,缺省时用 "update posts: <时间戳>"。
#   - 无未提交改动时跳过 commit/push,只重新生成并部署。
# 可用环境变量覆盖默认值:
#   HEXO_BLOG_DIR       博客源码仓库目录(默认 ~/github/igoingdown/hexo-posts)
#   HEXO_NODE_VERSION   构建用的 Node 版本(默认 18)
hdeploy() {
    local blog_dir="${HEXO_BLOG_DIR:-$HOME/github/igoingdown/hexo-posts}"
    local node_version="${HEXO_NODE_VERSION:-18}"
    local msg="$1"

    if [ ! -d "$blog_dir" ]; then
        echo "Error: blog dir not found: $blog_dir (set HEXO_BLOG_DIR to override)."
        return 1
    fi

    # 切到能构建的 Node 版本。
    load_nvm
    nvm use "$node_version" >/dev/null 2>&1 || {
        echo "Error: Node $node_version not installed in nvm. Run: nvm install $node_version"
        return 1
    }

    cd "$blog_dir" || return 1

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: $blog_dir is not a git repository."
        return 1
    fi

    # 提交并推送源码;无改动则跳过。
    if [ -n "$(git status --porcelain)" ]; then
        if [ -z "$msg" ]; then
            msg="update posts: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        git add . || return 1
        git commit -m "$msg" || return 1
        git push origin "$(git_current_branch)" || return 1
    else
        echo "No source changes to commit; rebuilding and deploying only."
    fi

    # 渲染并部署上线。
    npx hexo clean || return 1
    npx hexo generate || return 1
    npx hexo deploy || return 1

    echo "hdeploy done. Site: https://igoingdown.github.io/"
}

#=============== Git Functions =============================================
# after status and diff, push it through
gacp(){
	gs
    fail_report
    git add .
    fail_report
    git commit -m "$1"
    fail_report
    gps origin $2
    fail_report
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

# 当前分支名(供 gpsup 等别名用);不在 git 仓库时静默返回空。
git_current_branch() {
    git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

# 探测主分支名(main/trunk/master 顺序优先),供 gcm 用;都不存在则回退 master。
git_main_branch() {
    command git rev-parse --git-dir >/dev/null 2>&1 || return
    local ref
    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,master}; do
        if command git show-ref -q --verify "$ref"; then
            echo "${ref##*/}"
            return
        fi
    done
    echo master
}

#=============== Proxy Functions =============================================
proxy() {
    local proxy_ip=${PROXY_IP:-127.0.0.1}
    local proxy_port=${PROXY_PORT:-8080}
    export http_proxy=http://${proxy_ip}:${proxy_port}
    export https_proxy=http://${proxy_ip}:${proxy_port}
    export no_proxy="localhost,127.0.0.1,::1"
    echo "proxy: on"
}

noproxy() {
    unset http_proxy
    unset https_proxy
    unset all_proxy
    unset no_proxy
    echo "proxy: off"
}

xray_proxy() {
    local proxy_ip=${XRAY_PROXY_IP:-127.0.0.1}
    local proxy_port=${XRAY_PROXY_PORT:-1087}
    export http_proxy=http://${proxy_ip}:${proxy_port}
    export https_proxy=http://${proxy_ip}:${proxy_port}
    export all_proxy=socks5://${XRAY_SOCKS_IP:-127.0.0.1}:${XRAY_SOCKS_PORT:-1080}
    export no_proxy="localhost,127.0.0.1,::1"
    echo "proxy: on"
}


#=============== Common Functions =============================================
# find specified pattern under particular path recursively
deepfind() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Pattern and path are required."
        return 1
    fi
    grep -r "$1" "$2"
}

# find command line history
fh() {
    if [ -z "$1" ]; then
        echo "Error: Search pattern is required."
        return 1
    fi
    history | grep "$1"
}

# report error and stop running commands below
fail_report() {
    local last_exit=$?
    if [ $last_exit -ne 0 ]; then
        echo "Command failed with exit code $last_exit. Stopping."
        return 1
    fi
}

# 删除当前目录下文件名符合特定pattern的文件
rm_pattern_files() {
    if [ -z "$1" ]; then
        echo "Error: File pattern is required."
        return 1
    fi
    find -name "$1" | xargs rm -rf
}

# 在当前目录下创建特定conf的软链接
lcnf() {
    if [ -z "$1" ]; then
        echo "Error: Source file or directory is required."
        return 1
    fi
    ln -s "$1" conf
}

# 文件生成
# 参数表示文件和长度
pwfgen() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: File and length are required."
        return 1
    fi
    pwgen -H "$1" -Bncyv "$2" 1 | pbcopy
}

#=============== File Row Functions =============================================
## show_file_by_row show {$2}th line of file named {$1}
## $1 is the file name
## $2 is the start row
show_file_by_row(){
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: File name and row number are required."
        return 1
    fi
    head -"$2" "$1" | tail -1
}

## delete_and_run delete {$2}th line of file named {$1} and run shell scripts
## $1 is the file name
## $2 is the start row
delete_and_run(){
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: File name and row number are required."
        return 1
    fi
    sed -i "${2}d" "$1" && sh debug.sh
}

#=============== Quick Command Functions =============================================
stamp2time() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/timestamp.py $1
}
now_time() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/now_time.py
}
time2stamp() {
   python3 $HOME/github/python_demo_and_tool/tools/time_tools/time2stamp.py $1
}

#=============== Repo Functions =============================================
repo_name () {
    if [ -z "$1" ]; then
        echo "Error: Repository URL is required."
        return 1
    fi
    if command -v gsed >/dev/null 2>&1; then
        echo "$1" | gsed 's/.*:\(.*\)\.git/\1/'
    else
        echo "$1" | sed 's/.*:\(.*\)\.git/\1/'
    fi
}

#=============== PlantUML Functions =============================================
ppv() {
    if [ -z "$1" ]; then
        echo "Error: PlantUML file name is required."
        return 1
    fi
    if ! command -v plantuml >/dev/null 2>&1; then
        echo "Error: plantuml is not installed."
        return 1
    fi
    plantuml "$1.puml" || return 1
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1.png"
    else
        echo "Generated $1.png"
    fi
}

ppc() {
    if [ -z "$1" ]; then
        echo "Error: PlantUML file name is required."
        return 1
    fi
    cat "$1.puml" | pbcopy
}

#=============== NVM Functions =============================================
load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    return 0
}

#=============== ZSH Key Binding =============================================
if command -v bindkey >/dev/null 2>&1; then
    # 显式绑定 Option + J 到向后跳词
    bindkey "^[j" backward-word

    # 显式绑定 Option + L 到向前跳词
    bindkey "^[l" forward-word
fi
