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

#=============== Claude Code Functions =============================================
# Clear provider variables inherited from a stale shell/tmux environment before
# Claude Code loads the provider selected by cc-switch from its own settings.
# Keep this unalias for shells that sourced the previous alias-based config.
unalias claude 2>/dev/null
claude() {
    env \
        -u ANTHROPIC_BASE_URL \
        -u ANTHROPIC_AUTH_TOKEN \
        -u ANTHROPIC_API_KEY \
        /home/linuxbrew/.linuxbrew/bin/claude \
        --effort xhigh \
        --dangerously-skip-permissions \
        "$@"
}

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
# 端口只存在于 secrets.sh(git-ignored、按机器区分)。这里故意不留端口默认值:
# 本仓库跨多台机器共享, 各机器的 xray inbound 并不相同, 猜一个值会让所有 CLI
# 静默连到一个死端口, 且不报告任何与代理有关的信息。宁可显式失败。
# IP 仍默认回环 —— 本地代理监听在别处不是值得猜的情形。
#
# no_proxy 覆盖三段私有网段: 公司内网和开发机常在 10/8 与 172.16/12 上,
# 原来只排除 localhost 会让内网流量绕一趟代理再回来。
PROXY_NO_PROXY_DEFAULT="localhost,127.0.0.1,::1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,*.local"

# 把一个代理地址按生态里需要的所有拼写导出。
# 大小写都写不是双保险, 而是两边各缺一半: curl 只认小写 http_proxy
# (实测只设大写时 curl 直接直连), 而 Go 和多数 JVM / Ruby 工具链认大写。
_proxy_export() {
    local http_url=$1 socks_url=$2
    export http_proxy="$http_url" HTTP_PROXY="$http_url"
    export https_proxy="$http_url" HTTPS_PROXY="$http_url"
    if [ -n "$socks_url" ]; then
        export all_proxy="$socks_url" ALL_PROXY="$socks_url"
    fi
    export no_proxy="$PROXY_NO_PROXY_DEFAULT" NO_PROXY="$PROXY_NO_PROXY_DEFAULT"
    # Node >=24 的内置 fetch/undici 没有这个变量就完全忽略 *_proxy。
    # 任何用 fetch 的 node CLI 都需要。
    export NODE_USE_ENV_PROXY=1
}

# 普通上游 HTTP 代理(如公司代理), 与 xray 无关。
proxy() {
    if [ -z "$PROXY_PORT" ]; then
        echo "proxy: PROXY_IP/PROXY_PORT 未在 secrets.sh 中配置" >&2
        return 1
    fi
    _proxy_export "http://${PROXY_IP:-127.0.0.1}:${PROXY_PORT}" ""
    echo "proxy: on (${PROXY_IP:-127.0.0.1}:${PROXY_PORT})"
}

noproxy() {
    # 大小写和 NODE_USE_ENV_PROXY 都要清, 否则"关掉"之后生态里仍有一半在走代理。
    unset http_proxy https_proxy all_proxy no_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    unset NODE_USE_ENV_PROXY
    echo "proxy: off"
}

xray_proxy() {
    local missing=""
    [ -n "$XRAY_PROXY_PORT" ] || missing="XRAY_PROXY_PORT"
    [ -n "$XRAY_SOCKS_PORT" ] || missing="${missing:+$missing }XRAY_SOCKS_PORT"
    if [ -n "$missing" ]; then
        cat >&2 <<EOF
proxy: 未配置 -- $missing 为空。
  在 ${DOTFILES_ROOT:-$HOME/github/mydotfiles}/secrets.sh 里填上本机 xray 的 inbound 端口。
EOF
        return 1
    fi
    # socks5h 而非 socks5: 把主机名交给 xray 在远端解析。
    # 先在本地解析正是会被投毒的那一步。
    _proxy_export "http://${XRAY_PROXY_IP:-127.0.0.1}:${XRAY_PROXY_PORT}" \
                  "socks5h://${XRAY_SOCKS_IP:-127.0.0.1}:${XRAY_SOCKS_PORT}"
    echo "proxy: on (${XRAY_PROXY_IP:-127.0.0.1}:${XRAY_PROXY_PORT}, socks ${XRAY_SOCKS_PORT})"
}

# 代理端口是否真的在监听。用 -w 而非 mac 上的 -G: -G 是 BSD nc 专属,
# Linux 的 netcat-openbsd 不认这个 flag。
proxy_port_alive() {
    local ip=${XRAY_PROXY_IP:-127.0.0.1}
    [ -n "$XRAY_PROXY_PORT" ] || return 1
    nc -z -w 1 "$ip" "$XRAY_PROXY_PORT" >/dev/null 2>&1
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
