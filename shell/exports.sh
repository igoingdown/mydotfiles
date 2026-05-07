#=============== Golang Setting =============================================
export GOPATH="$HOME/golang"
export GOBIN=$HOME/golang/bin
# Note: add_to_path is defined in shell/paths.sh
add_to_path "$GOPATH/bin"
add_to_path "/opt/homebrew/opt/go@1.24/bin"
export GOPROXY="https://goproxy.cn,direct"
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
export GOSUMDB="sum.golang.google.cn"
export GONOSUMDB="*.byted.org,*.everphoto.cn,git.smartisan.com,cloud.google.com/*"
export GOOS="darwin"
export GOROOT="/opt/homebrew/opt/go@1.25/libexec"
export GOTOOLCHAIN=local

add_to_path "$GOROOT/bin"

#=============== ETCD Setting =============================================
export ETCDCTL_API=3

#=============== protobuffer version Setting =============================================
# need install protobuffer 2.6.1 first
export LD_LIBRARY_PATH=/usr/local/lib

#=============== python setting =============================================
export PYTHONPATH=$PYTHONPATH:"$HOME/repos/toutiao/app:$HOME/repos/toutiao/lib:/$HOME/repos/toutiao/lib/python_package/lib/python2.7/site-packages:$HOME/repos/toutiao/lib/python_package"

#=============== plantuml config =============================================
export PLANTUML_LIMIT_SIZE=65536

#=============== sonic compile config =============================================
export GOARCH=arm64

#=============== rust config =============================================
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

#=============== tce api config =============================================
export API_KEY=${TCE_API_KEY}



#=============== CCR config =============================================
export ANTHROPIC_AUTH_TOKEN="test"
export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
export NO_PROXY="127.0.0.1"
export DISABLE_TELEMETRY="true"
export DISABLE_COST_WARNINGS="true"
export API_TIMEOUT_MS="600000"
unset CLAUDE_CODE_USE_BEDROCK
