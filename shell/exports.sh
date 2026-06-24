#=============== Golang Setting =============================================
# GOPATH follows the Go default ($HOME/go); GOBIN is left unset so `go install`
# uses $GOPATH/bin. GOROOT is intentionally not set (brew / system Go reports it).
export GOPATH="$HOME/go"
# Ensure $GOPATH/bin is on PATH even before it exists (created on first `go install`).
case ":$PATH:" in
    *":$GOPATH/bin:"*) ;;
    *) export PATH="$GOPATH/bin:$PATH" ;;
esac
export GOPROXY="https://goproxy.cn,direct"
export GOSUMDB="sum.golang.google.cn"
export GOTOOLCHAIN=local

#=============== ETCD Setting =============================================
export ETCDCTL_API=3

#=============== protobuffer version Setting =============================================
# need install protobuffer 2.6.1 first
export LD_LIBRARY_PATH=/usr/local/lib

#=============== plantuml config =============================================
export PLANTUML_LIMIT_SIZE=65536

#=============== rust config =============================================
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

#=============== tce api config =============================================
# TCE_API_KEY is defined in secrets.sh (not committed).
export API_KEY="${TCE_API_KEY}"
