#!/bin/zsh
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/common_init_funcs.sh
source ${DOTFILES_ROOT}/shell/functions.sh
INTERFACE="Wi-Fi"

# Endpoints come from secrets.sh via _proxy_resolve; no defaults here, so a
# machine with unconfigured ports fails loudly instead of using someone else's.
if ! _proxy_resolve verbose; then
    exit 1
fi
PROXY_IP="${XRAY_PROXY_IP:-127.0.0.1}"
PROXY_PORT="${XRAY_PROXY_PORT}"
SOCKS_IP="${XRAY_SOCKS_IP:-127.0.0.1}"
SOCKS_PORT="${XRAY_SOCKS_PORT}"
HTTP_PROXY_URL="$_px_http"
SOCKS_PROXY_URL="$_px_socks"
NO_PROXY_VALUE="$PROXY_NO_PROXY_DEFAULT"

wait_for_proxy() {
    local retries=40
    while [ "$retries" -gt 0 ]; do
        if nc -z "$PROXY_IP" "$PROXY_PORT" >/dev/null 2>&1 && nc -z "$SOCKS_IP" "$SOCKS_PORT" >/dev/null 2>&1; then
            return 0
        fi
        retries=$((retries - 1))
        sleep 0.2
    done
    return 1
}

system_proxy_enabled() {
    networksetup -getwebproxy "$INTERFACE" | grep -q "Enabled: Yes" &&
    networksetup -getsecurewebproxy "$INTERFACE" | grep -q "Enabled: Yes" &&
    networksetup -getsocksfirewallproxy "$INTERFACE" | grep -q "Enabled: Yes"
}

set_launchd_proxy() {
    launchctl setenv HTTP_PROXY "$HTTP_PROXY_URL"
    launchctl setenv HTTPS_PROXY "$HTTP_PROXY_URL"
    launchctl setenv ALL_PROXY "$SOCKS_PROXY_URL"
    launchctl setenv NO_PROXY "$NO_PROXY_VALUE"
    launchctl setenv http_proxy "$HTTP_PROXY_URL"
    launchctl setenv https_proxy "$HTTP_PROXY_URL"
    launchctl setenv all_proxy "$SOCKS_PROXY_URL"
    launchctl setenv no_proxy "$NO_PROXY_VALUE"
    # GUI-launched node apps ignore *_proxy without this.
    launchctl setenv NODE_USE_ENV_PROXY 1
}

unset_launchd_proxy() {
    for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy NODE_USE_ENV_PROXY; do
        launchctl unsetenv "$name"
    done
}

show_status() {
    echo "📊 当前状态:"
    echo "HTTP:  $(networksetup -getwebproxy "$INTERFACE" | grep Enabled)"
    echo "HTTPS: $(networksetup -getsecurewebproxy "$INTERFACE" | grep Enabled)"
    echo "SOCKS: $(networksetup -getsocksfirewallproxy "$INTERFACE" | grep Enabled)"
    echo
    echo "🔌 端口状态:"
    nc -z "$PROXY_IP" "$PROXY_PORT" >/dev/null 2>&1 && echo "HTTP proxy port ${PROXY_IP}:${PROXY_PORT}: ok" || echo "HTTP proxy port ${PROXY_IP}:${PROXY_PORT}: closed"
    nc -z "$SOCKS_IP" "$SOCKS_PORT" >/dev/null 2>&1 && echo "SOCKS proxy port ${SOCKS_IP}:${SOCKS_PORT}: ok" || echo "SOCKS proxy port ${SOCKS_IP}:${SOCKS_PORT}: closed"
    echo
    echo "🚀 launchd proxy env:"
    echo "HTTP_PROXY:  $(launchctl getenv HTTP_PROXY)"
    echo "HTTPS_PROXY: $(launchctl getenv HTTPS_PROXY)"
    echo "ALL_PROXY:   $(launchctl getenv ALL_PROXY)"
    echo "NO_PROXY:    $(launchctl getenv NO_PROXY)"
    echo "NODE_USE_ENV_PROXY: $(launchctl getenv NODE_USE_ENV_PROXY)"
    echo
    # The system proxy survives reboot but launchctl setenv does not, so this
    # pair drifts apart on every boot: GUI apps stay proxied while CLIs go
    # direct with no visible cause. Call it out rather than printing two
    # unrelated-looking blocks and leaving the reader to spot it.
    if system_proxy_enabled && [ -z "$(launchctl getenv HTTP_PROXY)" ]; then
        echo "⚠️  系统代理已启用，但 launchd 代理环境为空 (通常是重启后的正常现象)。"
        echo "   GUI 应用仍走代理，新启动的 CLI 不会继承 -> 运行 'pt sync' 修复。"
    fi
}

if [ "$1" = "on" ]; then
    echo "🔄 启用Xray代理..."
    brew services restart xray
    if ! wait_for_proxy; then
        echo "❌ Xray代理端口未就绪 (探测 ${PROXY_IP}:${PROXY_PORT} 和 ${SOCKS_IP}:${SOCKS_PORT})，未写入系统代理和launchd环境变量"
        return 1 2>/dev/null || exit 1
    fi
    networksetup -setwebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsecurewebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsocksfirewallproxy "$INTERFACE" "$SOCKS_IP" "$SOCKS_PORT"
    networksetup -setwebproxystate "$INTERFACE" on
    networksetup -setsecurewebproxystate "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    if ! system_proxy_enabled; then
        echo "❌ 系统代理未能在网络服务 \"$INTERFACE\" 上启用 (请确认该服务名正确)，未写入launchd环境变量"
        return 1 2>/dev/null || exit 1
    fi
    set_launchd_proxy
    echo "✅ 代理已启用"
    echo "ℹ️ 已打开launchd代理环境；已运行的GUI应用需要重启后才会继承"
    # Only affects this script's own process; the pt wrapper re-applies it to the
    # calling shell and reports there. Silenced to avoid a duplicate line.
    xray_proxy >/dev/null
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    unset_launchd_proxy
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off
    networksetup -setsocksfirewallproxystate "$INTERFACE" off
    brew services stop xray
    echo "❌ 代理已禁用"
    echo "ℹ️ 已清理launchd代理环境；已运行的GUI应用如仍异常，请重启应用"
    noproxy >/dev/null
elif [ "$1" = "status" ]; then
    show_status
elif [ "$1" = "sync" ]; then
    if system_proxy_enabled && wait_for_proxy; then
        set_launchd_proxy
        echo "✅ Xray端口可用且系统代理已启用，launchd代理环境已同步为开启"
    else
        unset_launchd_proxy
        echo "❌ Xray端口不可用或系统代理未启用，launchd代理环境已清理"
    fi
else
    echo "📖 使用方法:"
    echo "  $0 on      - 启用代理"
    echo "  $0 off     - 禁用代理"
    echo "  $0 status  - 查看代理状态"
    echo "  $0 sync    - 根据端口和系统代理状态同步launchd环境"
    echo
    show_status
fi
