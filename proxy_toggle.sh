#!/bin/bash

# Xray代理一键切换脚本

export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/shell/functions.sh

INTERFACE="Wi-Fi"  # 根据你的网络接口修改

if [ "$1" = "on" ]; then
    brew services restart xray
    echo "🔄 启用Xray代理..."
    networksetup -setwebproxy "$INTERFACE" 127.0.0.1 8080
    networksetup -setsocksfirewallproxy "$INTERFACE" 127.0.0.1 1080
    networksetup -setwebproxystate "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    echo "✅ 代理已启用"
    xray_proxy

elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsocksfirewallproxystate "$INTERFACE" off

    brew services stop xray
    echo "❌ 代理已禁用"
    noproxy

else
    echo "📖 使用方法:"
    echo "  $0 on   - 启用代理"
    echo "  $0 off  - 禁用代理"
    echo
    echo "📊 当前状态:"
    echo "HTTP: $(networksetup -getwebproxy "$INTERFACE" | grep Enabled)"
    echo "SOCKS: $(networksetup -getsocksfirewallproxy "$INTERFACE" | grep Enabled)"
fi
