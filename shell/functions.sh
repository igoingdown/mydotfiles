
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

#=============== Open File Functions =============================================
# open file with sublime 
sublime() {
    if [ -z "$1" ]; then
        echo "Error: File path is required."
        return 1
    fi
    open -a /Applications/Sublime\ Text.app "$1"
}
# open file with VSC 
vsc() {
    if [ -z "$1" ]; then
        echo "Error: File path is required."
        return 1
    fi
    open -a /Applications/Visual\ Studio\ Code.app "$1"
}
# execute bash scripts in a new terminal 
tm() {
    if [ -z "$1" ]; then
        echo "Error: Script path is required."
        return 1
    fi
    open -a Terminal.app "$1"
}
# open markdown file with typora 
tpr() {
    if [ -z "$1" ]; then
        echo "Error: Markdown file path is required."
        return 1
    fi
    open -a /Applications/Typora.app "$1"
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
# Ports live ONLY in secrets.sh (git-ignored, per-machine). There is no default
# here on purpose: this repo is shared across machines whose xray inbounds
# differ, and a guessed port sends every CLI to a dead socket while reporting
# nothing about proxies. Fail loudly instead. IP does default to loopback --
# a local proxy listening anywhere else is not a case worth guessing around.
PROXY_NO_PROXY_DEFAULT="localhost,127.0.0.1,::1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,*.local"

# Resolve xray endpoints into _px_http / _px_socks. Returns 1 (quietly, unless
# $1 is "verbose") when secrets.sh has not defined the ports.
_proxy_resolve() {
    local verbose=$1 missing=""
    [ -n "$XRAY_PROXY_PORT" ] || missing="XRAY_PROXY_PORT"
    [ -n "$XRAY_SOCKS_PORT" ] || missing="${missing:+$missing }XRAY_SOCKS_PORT"
    if [ -n "$missing" ]; then
        [ "$verbose" = verbose ] && cat >&2 <<EOF
proxy: not configured -- $missing unset.
  Set them in ${DOTFILES_ROOT:-$HOME/github/my_dot_files}/secrets.sh to match this machine's xray inbounds:
    jq '.inbounds[] | {protocol, port}' /opt/homebrew/etc/xray/config.json
EOF
        return 1
    fi
    _px_http="http://${XRAY_PROXY_IP:-127.0.0.1}:${XRAY_PROXY_PORT}"
    # socks5h, not socks5: hand the hostname to xray so DNS is resolved at the
    # far end. Resolving locally first is exactly what gets poisoned.
    _px_socks="socks5h://${XRAY_SOCKS_IP:-127.0.0.1}:${XRAY_SOCKS_PORT}"
    return 0
}

# Export one proxy endpoint pair under every spelling the ecosystem expects.
# Both cases are required, not belt-and-braces: curl reads lowercase only,
# while Go (gog) and most JVM/Ruby tooling read uppercase.
_proxy_export() {
    local http_url=$1 socks_url=$2
    export http_proxy="$http_url" HTTP_PROXY="$http_url"
    export https_proxy="$http_url" HTTPS_PROXY="$http_url"
    if [ -n "$socks_url" ]; then
        export all_proxy="$socks_url" ALL_PROXY="$socks_url"
    fi
    export no_proxy="$PROXY_NO_PROXY_DEFAULT" NO_PROXY="$PROXY_NO_PROXY_DEFAULT"
    # Node's built-in fetch/undici ignores *_proxy entirely without this
    # (Node >=24). Needed for openclaw and any other node CLI using fetch.
    export NODE_USE_ENV_PROXY=1
}

# Plain upstream HTTP proxy (corporate style). Unrelated to xray.
proxy() {
    if [ -z "$PROXY_PORT" ]; then
        echo "proxy: PROXY_IP/PROXY_PORT unset in secrets.sh" >&2
        return 1
    fi
    _proxy_export "http://${PROXY_IP:-127.0.0.1}:${PROXY_PORT}" ""
    echo "proxy: on (${PROXY_IP:-127.0.0.1}:${PROXY_PORT})"
}

noproxy() {
    # Must clear both cases and NODE_USE_ENV_PROXY, or "off" leaves half the
    # ecosystem still proxied.
    unset http_proxy https_proxy all_proxy no_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    unset NODE_USE_ENV_PROXY
    echo "proxy: off"
}

xray_proxy() {
    _proxy_resolve verbose || return 1
    _proxy_export "$_px_http" "$_px_socks"
    echo "proxy: on ($_px_http, $_px_socks)"
}

# True when xray's HTTP inbound is actually accepting connections.
proxy_port_alive() {
    _proxy_resolve || return 1
    nc -z -G 1 -w 1 "${XRAY_PROXY_IP:-127.0.0.1}" "$XRAY_PROXY_PORT" >/dev/null 2>&1
}

# Startup guard, called from my_shell_config.sh.
#
# This exists because `pt on` persists asymmetrically: the macOS system proxy
# survives a reboot, but launchctl setenv does not. Every boot therefore lands
# in a split state where GUI apps stay proxied and every CLI silently loses its
# proxy. Probing the port on shell start re-derives the truth.
#
# Deliberately conditional rather than an unconditional export in .zshrc: an
# unconditional export would make `pt off` come back to life in the next
# terminal. Since `pt off` stops the xray service, a dead port doubles as
# "the user turned it off". If pt off ever stops halting the service, this
# needs a real state file instead -- see _proxy_state_file below.
proxy_autoinit() {
    proxy_port_alive || return 0
    _proxy_export "$_px_http" "$_px_socks"
}

# Reserved for the planned `pt off`-without-stopping-xray mode: at that point a
# live port no longer implies intent, and this file becomes the source of truth.
_proxy_state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/proxy.state"

# pt: wrapper for proxy_toggle.sh usable from any directory.
# proxy_toggle.sh is executed (not sourced), so its xray_proxy/noproxy calls
# only affect the script process; re-apply them here for the current shell.
pt() {
    "${DOTFILES_ROOT:-$HOME/github/my_dot_files}/proxy_toggle.sh" "$@" || return
    case "$1" in
        on)  xray_proxy ;;
        off) noproxy ;;
    esac
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
    find . -name "$1" -print0 | xargs -0 rm -rf
}

# 使用doas运行测试, 需要两个参数，分别是服务psm和需要运行的测试函数名
got() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Service PSM and test function name are required."
        return 1
    fi
    doas -p "$1" go test -v -run "$2"
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

#=============== Quick Command Functions =============================================
chrome() {
   open -a 'Google Chrome' "$@"
}

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
    echo "$1" | gsed 's/.*:\(.*\)\.git/\1/'
}

#=============== PlantUML Functions =============================================
ppv() {
    if [ -z "$1" ]; then
        echo "Error: PlantUML file name is required."
        return 1
    fi
    plantuml "$1.puml" && open "$1.png"
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
