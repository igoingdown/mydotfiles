#!/bin/zsh
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/shell/functions.sh
INTERFACE="Wi-Fi"

if [ "$1" = "on" ]; then
    brew services restart xray
    echo "🔄 启用Xray代理..."
    networksetup -setwebproxy "$INTERFACE" 127.0.0.1 8080
    networksetup -setsecurewebproxy "$INTERFACE" 127.0.0.1 8080  # ← 新增 HTTPS
    networksetup -setsocksfirewallproxy "$INTERFACE" 127.0.0.1 1080
    networksetup -setwebproxystate "$INTERFACE" on
    networksetup -setsecurewebproxystate "$INTERFACE" on          # ← 新增 HTTPS
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    export https_proxy=http://127.0.0.1:8080
    export http_proxy=http://127.0.0.1:8080
    export all_proxy=socks5://127.0.0.1:1080                     # ← 修正端口
    echo "✅ 代理已启用"
    xray_proxy
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off         # ← 新增 HTTPS
    networksetup -setsocksfirewallproxystate "$INTERFACE" off
    unset https_proxy
    unset http_proxy
    unset all_proxy
    brew services stop xray
    echo "❌ 代理已禁用"
    noproxy
else
    echo "📖 使用方法:"
    echo "  $0 on   - 启用代理"
    echo "  $0 off  - 禁用代理"
    echo
    echo "📊 当前状态:"
    echo "HTTP:  $(networksetup -getwebproxy "$INTERFACE" | grep Enabled)"
    echo "HTTPS: $(networksetup -getsecurewebproxy "$INTERFACE" | grep Enabled)"  # ← 新增
    echo "SOCKS: $(networksetup -getsocksfirewallproxy "$INTERFACE" | grep Enabled)"
fi
