# proxy_toggle.sh Launchd Proxy Environment Plan

## Background

`proxy_toggle.sh` already manages three things:

- Starts and stops Xray through `brew services`.
- Enables and disables macOS network proxies through `networksetup`.
- Calls shell helper functions such as `xray_proxy` and `noproxy`.

The missing piece is GUI application inheritance. Superset, Claude Desktop, Cursor, and their embedded agents are usually launched by the current user's `launchd` session rather than by an interactive shell. They may not inherit variables exported from `.zshrc`, and they may not consistently read macOS `networksetup` proxy settings.

To make GUI-launched agents use the same proxy, `proxy_toggle.sh` should also write standard proxy variables into the current user's `launchd` environment with `launchctl setenv`, and remove them with `launchctl unsetenv`.

## Preconditions

Before implementing this plan:

- Commit the existing uncommitted working-tree changes first (the `proxy_toggle.sh` variable extraction and the `shell/functions.sh` port change `8080` → `1087`) as a separate commit, then implement this plan on top of a clean baseline. Mixing two unrelated change sets into one diff makes review and rollback harder.
- **Fix `config.example.sh` so `XRAY_PROXY_PORT` is `1087`, not `8080`.** This is a P0 blocker: `proxy_toggle.sh` now `source`s `common_init_funcs.sh`, which `source`s `secrets.sh`. If the user copied `secrets.sh` from `config.example.sh`, the stale `XRAY_PROXY_PORT="8080"` overrides the script default `:-1087`. Xray actually listens on `1087`, so the new `wait_for_proxy` would probe `127.0.0.1:8080`, fail, and make `on` exit 1 every time — while Xray has already been restarted, leaving a "service running but proxy not configured" half state. The script default, `xray_proxy` (`shell/functions.sh`), and `config.example.sh` must all agree on `1087`.
- Check the local, untracked `secrets.sh` before testing. If it contains a stale `XRAY_PROXY_PORT="8080"`, update it locally to `1087`, but do not commit `secrets.sh`.

## Goals

- Keep `proxy_toggle.sh on` as the single command that turns on Xray, macOS system proxy, shell proxy helper behavior, and GUI-app proxy inheritance.
- Keep `proxy_toggle.sh off` as the single command that turns off macOS system proxy, removes GUI-app proxy inheritance, and stops Xray.
- Avoid setting launchd proxy variables if Xray ports are not actually listening.
- Add status output that shows all relevant layers: `networksetup`, `launchd`, and local proxy ports.
- Preserve the current configurable defaults based on `XRAY_PROXY_IP`, `XRAY_PROXY_PORT`, `XRAY_SOCKS_IP`, and `XRAY_SOCKS_PORT`.
- Avoid changing unrelated shell functions or dotfiles behavior in this change.

## Non-Goals

- Do not create a LaunchAgent plist in this change.
- Do not auto-monitor Xray in the background in this change.
- Do not change Homebrew service management beyond the existing `brew services restart xray` and `brew services stop xray` behavior.
- Do not change VPN/Xray routing rules.
- Do not make already-running GUI apps pick up new environment variables. macOS process environments cannot be retroactively changed; affected apps still need a restart.

## Current State

Current `proxy_toggle.sh`:

```zsh
#!/bin/zsh
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/common_init_funcs.sh
source ${DOTFILES_ROOT}/shell/functions.sh
INTERFACE="Wi-Fi"

PROXY_IP="${XRAY_PROXY_IP:-127.0.0.1}"
PROXY_PORT="${XRAY_PROXY_PORT:-1087}"
SOCKS_IP="${XRAY_SOCKS_IP:-127.0.0.1}"
SOCKS_PORT="${XRAY_SOCKS_PORT:-1080}"

if [ "$1" = "on" ]; then
    brew services restart xray
    echo "🔄 启用Xray代理..."
    networksetup -setwebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsecurewebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsocksfirewallproxy "$INTERFACE" "$SOCKS_IP" "$SOCKS_PORT"
    networksetup -setwebproxystate "$INTERFACE" on
    networksetup -setsecurewebproxystate "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    echo "✅ 代理已启用"
    xray_proxy
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off
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
    echo "HTTP:  $(networksetup -getwebproxy "$INTERFACE" | grep Enabled)"
    echo "HTTPS: $(networksetup -getsecurewebproxy "$INTERFACE" | grep Enabled)"
    echo "SOCKS: $(networksetup -getsocksfirewallproxy "$INTERFACE" | grep Enabled)"
fi
```

Important limitation: when this file is executed as `./proxy_toggle.sh on`, the `xray_proxy` exports only affect the script process and its children. They do not persist in the caller's terminal after the script exits. The durable side effects are currently `brew services` and `networksetup`.

## Proposed Design

Add explicit `launchd` environment management to `proxy_toggle.sh`.

The script will manage three environment scopes:

- macOS system proxy: `networksetup`.
- GUI application future process environment: `launchctl setenv` / `launchctl unsetenv`.
- Script-local shell process environment: existing `xray_proxy` / `noproxy` calls, retained for compatibility even though they do not affect the caller when the script is executed normally.

Add helpers:

- `wait_for_proxy`: checks whether both HTTP and SOCKS proxy ports are listening before enabling proxy settings.
- `system_proxy_enabled`: checks whether the configured macOS network service has HTTP, HTTPS, and SOCKS proxies enabled.
- `set_launchd_proxy`: writes uppercase and lowercase proxy variables into the user `launchd` environment.
- `unset_launchd_proxy`: removes uppercase and lowercase proxy variables from the user `launchd` environment.
- `show_status`: prints `networksetup`, `launchd`, and port status.

Add commands:

- `status`: explicitly show status.
- `sync`: reconcile launchd proxy variables with the actual desired proxy state. `sync` sets launchd proxy variables only when both conditions are true: Xray proxy ports are listening and macOS `networksetup` proxy state is enabled for the configured interface. Otherwise, it removes launchd proxy variables.

Keep existing default behavior:

- Any unsupported argument currently prints usage and status. This should remain true, but status output will become more complete.

## Line-by-Line Implementation Plan

### 1. Add URL and no-proxy constants after existing proxy host and port variables

After the current line:

```zsh
SOCKS_PORT="${XRAY_SOCKS_PORT:-1080}"
```

Add:

```zsh
HTTP_PROXY_URL="http://${PROXY_IP}:${PROXY_PORT}"
```

Why:

- `launchctl setenv` expects a single string value.
- Standard tools expect `HTTP_PROXY` and `HTTPS_PROXY` values in URL form, not separate host and port fields.
- Reusing this variable avoids repeating `http://${PROXY_IP}:${PROXY_PORT}` multiple times.

Add:

```zsh
SOCKS_PROXY_URL="socks5://${SOCKS_IP}:${SOCKS_PORT}"
```

Why:

- `socks5` resolves DNS locally before handing the IP to the proxy. The Xray client already handles DNS for proxied traffic, so local resolution is not a problem here.
- `socks5` matches the repo convention in `AGENTS.md` ("Proxy helpers should export standard URL forms, for example `socks5://127.0.0.1:1080`") and the existing `xray_proxy` helper, keeping the launchd layer and the interactive-shell layer consistent.
- `socks5h` (DNS delegated to the proxy) was considered for anti-DNS-leak reasons but rejected to avoid splitting semantics between launchd and `xray_proxy`. If switching to `socks5h` later, update `xray_proxy` at the same time so both layers agree.

Add:

```zsh
NO_PROXY_VALUE="localhost,127.0.0.1,::1"
```

Why:

- Localhost traffic should not be sent through Xray.
- IPv4 and IPv6 loopback should both bypass the proxy.
- The previous `*.byted.org` entry is intentionally dropped: the `*.` wildcard form is not honored by curl or Python's requests (only bare-domain / leading-dot suffix matching is portable), and the internal-domain bypass is no longer needed.
- Private LAN ranges (`10.0.0.0/8`, `192.168.0.0/16`, etc.) and `*.local` are intentionally not added for now; revisit if LAN services start getting incorrectly routed through the proxy.
- Centralizing this value ensures shell and launchd proxy bypasses can stay consistent later.

### 2. Add `wait_for_proxy` helper

Add this function after the constants and before the `if [ "$1" = "on" ]` block:

```zsh
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
```

Why line by line:

- `wait_for_proxy() {`: creates a small reusable check for Xray readiness.
- `local retries=40`: allows up to about 8 seconds for `brew services restart xray` to bring ports up. The previous 4-second budget could be too tight for a cold start.
- `while [ "$retries" -gt 0 ]; do`: retries because service startup is not always instant.
- `if nc -z "$PROXY_IP" "$PROXY_PORT" ... && nc -z "$SOCKS_IP" "$SOCKS_PORT" ...; then`: verifies both HTTP proxy and SOCKS proxy ports are accepting TCP connections.
- `>/dev/null 2>&1`: keeps normal output clean; status output is handled elsewhere.
- `return 0`: reports success when both ports are ready.
- `retries=$((retries - 1))`: moves toward timeout.
- `sleep 0.2`: avoids busy-looping while still staying responsive.
- `return 1`: reports failure if ports never become ready. The caller is responsible for printing which `IP:PORT` it was probing, so a port misconfiguration (e.g. stale `8080` in `secrets.sh`) is distinguishable from "Xray failed to start".

### 3. Add `system_proxy_enabled` and `set_launchd_proxy` helpers

Add `system_proxy_enabled` after `wait_for_proxy`:

```zsh
system_proxy_enabled() {
    networksetup -getwebproxy "$INTERFACE" | grep -q "Enabled: Yes" &&
    networksetup -getsecurewebproxy "$INTERFACE" | grep -q "Enabled: Yes" &&
    networksetup -getsocksfirewallproxy "$INTERFACE" | grep -q "Enabled: Yes"
}
```

Why line by line:

- `system_proxy_enabled() {`: separates "Xray process is alive" from "the user has proxy mode enabled for this macOS network service".
- Each `networksetup -get... | grep -q "Enabled: Yes"` line checks one proxy layer that `proxy_toggle.sh on` enables.
- The `&&` chain requires HTTP, HTTPS, and SOCKS to all be enabled. This keeps `sync` conservative: a partial or disabled system-proxy state should not cause launchd proxy variables to be written.
- This helper is used by both `sync` (as the cheap, short-circuiting precondition) and `on` (as a post-`networksetup` verification step that catches a wrong/renamed network service before launchd variables are written).

Add after `system_proxy_enabled`:

```zsh
set_launchd_proxy() {
    launchctl setenv HTTP_PROXY "$HTTP_PROXY_URL"
    launchctl setenv HTTPS_PROXY "$HTTP_PROXY_URL"
    launchctl setenv ALL_PROXY "$SOCKS_PROXY_URL"
    launchctl setenv NO_PROXY "$NO_PROXY_VALUE"
    launchctl setenv http_proxy "$HTTP_PROXY_URL"
    launchctl setenv https_proxy "$HTTP_PROXY_URL"
    launchctl setenv all_proxy "$SOCKS_PROXY_URL"
    launchctl setenv no_proxy "$NO_PROXY_VALUE"
}
```

Why line by line:

- `set_launchd_proxy() {`: isolates GUI-environment setup from system proxy setup.
- `launchctl setenv HTTP_PROXY "$HTTP_PROXY_URL"`: sets the standard uppercase HTTP proxy variable for future GUI-launched processes.
- `launchctl setenv HTTPS_PROXY "$HTTP_PROXY_URL"`: sets the HTTPS proxy variable; most important for Web Search, Fetch, GitHub, package managers, and API calls.
- `launchctl setenv ALL_PROXY "$SOCKS_PROXY_URL"`: gives tools that support a generic proxy variable a SOCKS fallback that matches the existing `xray_proxy` helper's `socks5://` semantics.
- `launchctl setenv NO_PROXY "$NO_PROXY_VALUE"`: prevents local and selected internal traffic from being proxied.
- Lowercase variants are also set because some tools only read lowercase names, especially Unix CLI tools and older libraries.
- The function does not echo by itself so callers can control user-facing messages.

### 4. Add `unset_launchd_proxy` helper

Add after `set_launchd_proxy`:

```zsh
unset_launchd_proxy() {
    for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
        launchctl unsetenv "$name"
    done
}
```

Why line by line:

- `unset_launchd_proxy() {`: isolates GUI-environment cleanup from system proxy cleanup.
- `for name in ...; do`: avoids eight repeated `launchctl unsetenv` calls.
- Includes both uppercase and lowercase names to fully clean up what `set_launchd_proxy` writes.
- `launchctl unsetenv "$name"`: removes the variable from future GUI-launched processes.

Important behavior:

- This cannot change already-running GUI app processes.
- Superset / Claude Desktop / Cursor should still be restarted after `off` if they were launched while proxy variables were set.

### 5. Add `show_status` helper

Add after `unset_launchd_proxy`:

```zsh
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
}
```

Why line by line:

- `show_status() {`: avoids duplicating status output in default and explicit `status` branches.
- First three `networksetup` lines preserve the current status behavior.
- Blank `echo` calls visually separate system proxy, port status, and launchd status.
- `nc -z ...`: confirms whether the configured local proxy ports are actually listening.
- `launchctl getenv ...`: shows what future GUI applications will inherit.
- Uppercase variables are shown because those are the most conventional and most relevant to GUI-launched agents.

### 6. Modify the `on` branch to wait for Xray and set launchd env

Current branch:

```zsh
if [ "$1" = "on" ]; then
    brew services restart xray
    echo "🔄 启用Xray代理..."
    networksetup -setwebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsecurewebproxy "$INTERFACE" "$PROXY_IP" "$PROXY_PORT"
    networksetup -setsocksfirewallproxy "$INTERFACE" "$SOCKS_IP" "$SOCKS_PORT"
    networksetup -setwebproxystate "$INTERFACE" on
    networksetup -setsecurewebproxystate "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    echo "✅ 代理已启用"
    xray_proxy
```

Planned replacement:

```zsh
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
    xray_proxy
```

Why line by line:

- Move `echo "🔄 启用Xray代理..."` before restarting Xray so the user sees what is happening immediately.
- Keep `brew services restart xray` because the current script's core behavior is to own Xray service state.
- `if ! wait_for_proxy; then`: prevents writing bad proxy settings when Xray fails to start.
- The failure message prints the exact `IP:PORT` pairs it probed, so a port misconfiguration (such as a stale `XRAY_PROXY_PORT="8080"` in `secrets.sh`) is immediately distinguishable from "Xray failed to start". See Preconditions.
- Failure message explicitly says system proxy and launchd variables were not written.
- `return 1 2>/dev/null || exit 1`: makes failures visible to callers and automation while avoiding closing the current terminal if the script is accidentally sourced. (`|| exit 1` is a fallback for non-zsh execution; under this script's `#!/bin/zsh` in execute mode, `return` at top level already terminates the script with the given code.)
- `if ! system_proxy_enabled; then`: after issuing the `networksetup` calls, verify the system proxy is actually enabled on `$INTERFACE` before writing launchd variables. This catches a wrong/renamed network service name (e.g. `networksetup -setwebproxystate "BadName" on` returns a non-zero exit code) instead of falsely printing "代理已启用". Verifying the resulting state (rather than checking each command's `$?`) is more robust — it also covers the case where a `-set` call "succeeds" but the state does not take effect — and avoids the zsh pitfall where `local r=$(cmd)` swallows `cmd`'s exit code.
- `set_launchd_proxy`: adds the missing GUI-app inheritance layer, reached only after the system proxy is confirmed enabled.
- Success message remains.
- Additional info message documents the process-environment limitation.
- Keep `xray_proxy` for compatibility with existing user expectations, even though it does not persist to the parent shell when the script is executed normally.

### 7. Modify the `off` branch to unset launchd env before stopping Xray

Current branch:

```zsh
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off
    networksetup -setsocksfirewallproxystate "$INTERFACE" off
    brew services stop xray
    echo "❌ 代理已禁用"
    noproxy
```

Planned replacement:

```zsh
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    unset_launchd_proxy
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off
    networksetup -setsocksfirewallproxystate "$INTERFACE" off
    brew services stop xray
    echo "❌ 代理已禁用"
    echo "ℹ️ 已清理launchd代理环境；已运行的GUI应用如仍异常，请重启应用"
    noproxy
```

Why line by line:

- `unset_launchd_proxy` runs early to reduce the window where future GUI apps could inherit stale proxy values.
- Existing `networksetup` disable lines are preserved.
- Existing `brew services stop xray` is preserved.
- Additional info message explains why already-running apps may still behave as if proxy is enabled.
- Keep `noproxy` for compatibility with current behavior.

### 8. Add explicit `status` command and reuse `show_status`

Current default branch:

```zsh
else
    echo "📖 使用方法:"
    echo "  $0 on   - 启用代理"
    echo "  $0 off  - 禁用代理"
    echo
    echo "📊 当前状态:"
    echo "HTTP:  $(networksetup -getwebproxy "$INTERFACE" | grep Enabled)"
    echo "HTTPS: $(networksetup -getsecurewebproxy "$INTERFACE" | grep Enabled)"
    echo "SOCKS: $(networksetup -getsocksfirewallproxy "$INTERFACE" | grep Enabled)"
fi
```

Planned replacement:

```zsh
elif [ "$1" = "status" ]; then
    show_status
else
    echo "📖 使用方法:"
    echo "  $0 on      - 启用代理"
    echo "  $0 off     - 禁用代理"
    echo "  $0 status  - 查看代理状态"
    echo "  $0 sync    - 根据端口和系统代理状态同步launchd环境"
    echo
    show_status
fi
```

Why line by line:

- Add a real `status` command for quick checks and future automation.
- Keep the no-argument behavior useful by still printing usage and status.
- Replace repeated `networksetup` status code with `show_status` so future status fields stay in one place.

### 9. Add explicit `sync` command

Add this branch between `status` and the final `else` branch:

```zsh
elif [ "$1" = "sync" ]; then
    if system_proxy_enabled && wait_for_proxy; then
        set_launchd_proxy
        echo "✅ Xray端口可用且系统代理已启用，launchd代理环境已同步为开启"
    else
        unset_launchd_proxy
        echo "❌ Xray端口不可用或系统代理未启用，launchd代理环境已清理"
    fi
```

Why line by line:

- `elif [ "$1" = "sync" ]; then`: makes sync an explicit user-visible command.
- `if system_proxy_enabled && wait_for_proxy; then`: avoids the dangerous behavior of setting launchd proxy variables merely because Xray is alive. The desired state is "proxy mode enabled", represented by both enabled macOS system proxy and ready local ports. The cheap check (`system_proxy_enabled`, ~0.05s) comes first so that when the system proxy is off (e.g. right after `off`), the `&&` short-circuits and `sync` cleans up immediately instead of waiting out `wait_for_proxy`'s full ~8s retry budget.
- `set_launchd_proxy`: writes launchd variables only when the proxy is both usable and intended to be on.
- The success message states both conditions so the user understands what was synchronized.
- `unset_launchd_proxy`: removes stale launchd variables when Xray is down, misconfigured, or the macOS system proxy is off.
- The cleanup message makes clear that either failed condition leads to cleanup.

## Expected Final `proxy_toggle.sh`

This is the intended full file after implementation:

```zsh
#!/bin/zsh
export DOTFILES_ROOT=${DOTFILES_ROOT:-$HOME/github/my_dot_files}
source ${DOTFILES_ROOT}/common_init_funcs.sh
source ${DOTFILES_ROOT}/shell/functions.sh
INTERFACE="Wi-Fi"

PROXY_IP="${XRAY_PROXY_IP:-127.0.0.1}"
PROXY_PORT="${XRAY_PROXY_PORT:-1087}"
SOCKS_IP="${XRAY_SOCKS_IP:-127.0.0.1}"
SOCKS_PORT="${XRAY_SOCKS_PORT:-1080}"
HTTP_PROXY_URL="http://${PROXY_IP}:${PROXY_PORT}"
SOCKS_PROXY_URL="socks5://${SOCKS_IP}:${SOCKS_PORT}"
NO_PROXY_VALUE="localhost,127.0.0.1,::1"

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
}

unset_launchd_proxy() {
    for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
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
    xray_proxy
elif [ "$1" = "off" ]; then
    echo "🔄 禁用Xray代理..."
    unset_launchd_proxy
    networksetup -setwebproxystate "$INTERFACE" off
    networksetup -setsecurewebproxystate "$INTERFACE" off
    networksetup -setsocksfirewallproxystate "$INTERFACE" off
    brew services stop xray
    echo "❌ 代理已禁用"
    echo "ℹ️ 已清理launchd代理环境；已运行的GUI应用如仍异常，请重启应用"
    noproxy
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
```

## Files To Change

Implementation phase should change `proxy_toggle.sh`, plus two mandatory companion changes:

- `proxy_toggle.sh`: the main change.
- `config.example.sh`: fix `XRAY_PROXY_PORT` to `1087` (P0, see Preconditions).
- `README.md`: document the new `proxy_toggle.sh status` and `proxy_toggle.sh sync` commands, plus the GUI-app restart requirement. `AGENTS.md` requires that new user-visible commands be documented in `README.md`, so this is not optional.

Optional later changes, not part of this plan unless explicitly requested:

- `shell/functions.sh`: make `xray_proxy` also export uppercase variables and update `no_proxy`; this is useful for interactive shell consistency but not necessary for fixing GUI Agent inheritance.

## Testing Plan

Static validation:

```bash
zsh -n proxy_toggle.sh
```

Status command validation:

```bash
./proxy_toggle.sh status
```

Enable flow validation:

```bash
./proxy_toggle.sh on
launchctl getenv HTTPS_PROXY
launchctl getenv ALL_PROXY
# IMPORTANT: a plain `curl` in this same terminal does NOT validate the proxy.
# The script's `xray_proxy` export does not flow back into the parent shell,
# `launchctl setenv` does not affect this already-running terminal process, and
# curl does not read the macOS networksetup system proxy. So a bare curl here
# is effectively a direct connection and gives a misleading result.
# Validate by explicitly injecting the launchd value, OR open a fresh terminal.
# NOTE: curl prefers a protocol-specific variable (HTTPS_PROXY) over the generic
# ALL_PROXY. So to genuinely exercise each path, strip the others with `env -u`,
# otherwise an ALL_PROXY test can silently ride a leftover HTTPS_PROXY and pass falsely.
env -u ALL_PROXY -u all_proxy HTTPS_PROXY="$(launchctl getenv HTTPS_PROXY)" curl -I -L --max-time 20 https://platform.claude.com/docs/en/managed-agents/define-outcomes.md
env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u https_proxy ALL_PROXY="$(launchctl getenv ALL_PROXY)" curl -I -L --max-time 20 https://platform.claude.com/docs/en/managed-agents/define-outcomes.md
```

Expected:

- `launchctl getenv HTTPS_PROXY` prints `http://127.0.0.1:1087`, or the configured custom value.
- `launchctl getenv ALL_PROXY` prints `socks5://127.0.0.1:1080`, or the configured custom value.
- `curl` (HTTPS proxy injected, ALL_PROXY stripped) reaches `200 text/markdown` rather than `app-unavailable-in-region`.
- `curl` (ALL_PROXY injected, HTTP/HTTPS proxy vars stripped) also reaches `200 text/markdown`, genuinely validating the SOCKS path used by tools that honor `ALL_PROXY`.

Disable flow validation:

```bash
./proxy_toggle.sh off
launchctl getenv HTTPS_PROXY
launchctl getenv ALL_PROXY
./proxy_toggle.sh status
./proxy_toggle.sh sync
```

Expected:

- `launchctl getenv HTTPS_PROXY` prints nothing.
- `launchctl getenv ALL_PROXY` prints nothing.
- `status` shows proxy ports closed if Xray was stopped successfully.
- `sync` leaves launchd proxy variables unset when Xray is stopped or system proxy is disabled.

Manual GUI validation:

1. Run `./proxy_toggle.sh on`.
2. Fully quit Superset / Claude Desktop / Cursor.
3. Reopen the target GUI app.
4. Verify the app actually inherited the variables (the main process inheriting them does not guarantee an embedded Node/Chromium runtime did):

   ```bash
   ps eww -p "$APP_PID" -o command= | tr ' ' '\n' | grep -i proxy
   ```

5. Start a new Code Agent session.
6. Ask the agent to fetch `https://platform.claude.com/docs/en/managed-agents/define-outcomes.md`.

Expected:

- New GUI-launched agent should inherit proxy variables (verify per app via `ps eww`; do not assume).
- Fetch/Web Search should no longer fail due to unsafe-domain verification caused by unavailable regional routing.
- If an app embeds its own runtime and still ignores the variables, fall back to launching the app binary or a wrapper script with explicit environment injection, e.g. `env HTTPS_PROXY=http://127.0.0.1:1087 /Applications/Claude.app/Contents/MacOS/Claude`. Avoid relying on `open --env`; `open` does not provide a portable general-purpose environment-injection flag.

## Acceptance Criteria

- `./proxy_toggle.sh on` starts Xray, waits for local proxy ports, enables macOS system proxy, and sets launchd proxy variables.
- `./proxy_toggle.sh off` removes launchd proxy variables, disables macOS system proxy, and stops Xray.
- `./proxy_toggle.sh status` reports macOS system proxy, local port readiness, and launchd proxy values.
- `./proxy_toggle.sh sync` sets launchd proxy variables only when Xray ports are ready and macOS system proxy is enabled; otherwise it clears launchd proxy variables.
- The script does not set launchd proxy variables when Xray ports are not ready.
- Existing custom env vars `XRAY_PROXY_IP`, `XRAY_PROXY_PORT`, `XRAY_SOCKS_IP`, and `XRAY_SOCKS_PORT` remain respected.
- Existing no-argument behavior still prints usage and status.

## Risks

- Already-running GUI apps will not pick up changed environment variables. This is a macOS process model limitation, not a script bug.
- **`launchctl setenv` does not persist across reboot / re-login.** The macOS system proxy set by `networksetup` *is* persistent, and `brew services` may auto-start Xray at boot. After a reboot this produces a split state: system proxy ON and Xray running, but the launchd proxy env is empty, so newly launched GUI agents do not get proxied and `status` shows a half-on/half-off picture. The `~/.launchd.conf` auto-load mechanism that used to fix this is long gone; persistence requires a LaunchAgent/login script or re-running `on`/`sync`. See the Sync section.
- **Apps that embed their own runtime may not inherit the variables even when the main process does.** Electron/Chromium and embedded Node runtimes have known cases (e.g. Codex Desktop's built-in Node REPL, Claude under proxy/VPN) where `launchctl setenv` reaching the main process does not propagate to nested runtimes. Treat inheritance as "should work, verify per app" (via `ps eww`), not guaranteed; fall back to launching the app binary or a wrapper script with explicit environment injection when needed.
- Prefer running this as `./proxy_toggle.sh on`, not `source proxy_toggle.sh on`. The failure path uses `return 1 2>/dev/null || exit 1`, so sourcing should not close the current terminal, but sourcing is still not the intended invocation model.
- `brew services restart xray` may report success before Xray is fully ready; `wait_for_proxy` mitigates this.
- If Xray is stopped outside this script, launchd variables can become stale. The `sync` command (see below) addresses this.
- `NO_PROXY_VALUE` may need additional hostnames (e.g. Docker, LAN services) depending on workflows. Note the `*.` wildcard form is not portable — use bare domains / leading-dot suffixes.
- Some tools treat uppercase and lowercase proxy variables differently. Setting both improves compatibility but may surprise users who expected only lowercase variables.
- `INTERFACE` is hardcoded to `Wi-Fi`. This matches the current laptop's Wi-Fi-only usage; on an Ethernet connection the system proxy would be set on the wrong service while launchd env is still set. Accepted as a known limitation, not changed in this plan.

## Sync Command

Because the reboot-induced split state above is a common scenario (not an edge case), a `sync` command is included in this iteration to reconcile the launchd env with actual desired proxy state.

Important semantic rule: `sync` must not set launchd variables just because Xray ports are open. It should set launchd variables only when macOS `networksetup` proxy state is enabled and Xray ports are open. This avoids surprising behavior where a background-running Xray service silently makes GUI apps use a proxy after the user has disabled system proxy.

Expected latency note: `sync` checks the cheap condition first (`system_proxy_enabled`, ~0.05s) and short-circuits on `&&`, so when the system proxy is off (e.g. right after `off`) it cleans up immediately without waiting. The only case that still waits out `wait_for_proxy`'s full retry budget (~8 seconds) is "system proxy is enabled but the Xray ports are not up" (e.g. Xray crashed); there the wait is justified because confirming the port state genuinely requires probing. This delay is expected and acceptable; `sync` is not on a hot path, and the double-condition still produces the correct final state regardless of the wait.

```zsh
elif [ "$1" = "sync" ]; then
    if system_proxy_enabled && wait_for_proxy; then
        set_launchd_proxy
        echo "✅ Xray端口可用且系统代理已启用，launchd代理环境已同步为开启"
    else
        unset_launchd_proxy
        echo "❌ Xray端口不可用或系统代理未启用，launchd代理环境已清理"
    fi
```

## Resolved Decisions

- **`NO_PROXY_VALUE`**: `localhost,127.0.0.1,::1` only. The `*.byted.org` entry is removed entirely (no longer needed), and private LAN ranges / `*.local` are intentionally not added for now.
- **SOCKS scheme**: use `socks5://` (not `socks5h://`), matching `AGENTS.md` and the existing `xray_proxy` helper.
- **`INTERFACE`**: keep hardcoded `Wi-Fi`; Ethernet is out of scope for the current usage (Wi-Fi only).
- **`sync` command**: include this iteration (see the Sync section), because reboot non-persistence makes the split state common. It must require both port readiness and system-proxy enabled state before setting launchd variables.
- **`README.md`**: must be updated (the new `status` and `sync` commands are user-visible; required by `AGENTS.md`).
- **`exit 1` / source guard**: use `return 1 2>/dev/null || exit 1` in the failure path so accidental sourcing does not close the current terminal.
