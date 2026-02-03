#=============== Dev Machine Functions =============================================
# copy local files to dev machine
dscp() {
    if [ -z "$1" ]; then
        echo "Error: Source file or directory is required."
        return 1
    fi
    scp -r "$1" "$DEV_USER_NAME@$DEV_IP:~/"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files to $DEV_IP."
    fi
}

# copy file on dev machine to local
cpb() {
	scp -r $DEV_USER_NAME@$DEV_IP:~/$1 ~/
}
# copy local files to new dev machine
ndscp() {
    if [ -z "$1" ]; then
        echo "Error: Source file or directory is required."
        return 1
    fi
    scp -r "$1" "$DEV_USER_NAME@$NEW_DEV_IP:~/"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files to $NEW_DEV_IP."
    fi
}

# copy file on dev machine to local
ncpb() {
    if [ -z "$1" ]; then
        echo "Error: Remote file or directory is required."
        return 1
    fi
    scp -r "$DEV_USER_NAME@$NEW_DEV_IP:~/$1" ~/
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files from $NEW_DEV_IP."
    fi
}

# copy file on dev machine to local with specified destination
cpbd() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Both remote file and local destination are required."
        return 1
    fi
    scp -r "$DEV_USER_NAME@$DEV_IP:~/$1" "$2"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files from $DEV_IP to specified destination."
    fi
}

# copy local files to online dev machine
odscp() {
    if [ -z "$1" ]; then
        echo "Error: Source file or directory is required."
        return 1
    fi
    scp -r "$1" "$DEV_USER_NAME@$ONLINE_DEV_IP:~/"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy files to $ONLINE_DEV_IP."
    fi
}

# copy file on online dev machine to local
ocpb() {
	scp -r $DEV_USER_NAME@$ONLINE_DEV_IP:~/$1 ~/
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

#=============== Proxy Functions =============================================
proxy() {
    export http_proxy=${PROXY_IP}:${PROXY_PORT}
    export https_proxy=${PROXY_IP}:${PROXY_PORT}
    export no_proxy=*.byted.org
    echo "proxy: on"
}

noproxy() {
    unset http_proxy
    unset https_proxy
    unset no_proxy
    echo "proxy: off"
}

xray_proxy() {
    export http_proxy=${XRAY_PROXY_IP}:${XRAY_PROXY_PORT}
    export https_proxy=${XRAY_PROXY_IP}:${XRAY_PROXY_PORT}
    export no_proxy=*.byted.org
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
    if [ $? -ne 0 ]; then
        echo "Command failed with exit code $?. Stopping execution."
        exit 1
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

#=============== PPE Functions =============================================
jump_ppe_by_psm () {
    cat ~/psm.txt | cut -f 1 -d " " | fzf | read psm
    ~/scripts/bytedance/byteshell_ppe.sh $psm
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
}

#=============== ZSH Key Binding =============================================
# 显式绑定 Option + J 到向后跳词
bindkey "^[j" backward-word

# 显式绑定 Option + L 到向前跳词
bindkey "^[l" forward-word
