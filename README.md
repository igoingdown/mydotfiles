# my dot files

This repository is used to manage all my dot configuration files, scripts, and development environment settings. It supports both macOS and Linux environments.

## 🚀 Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/igoingdown/mydotfiles.git ~/github/my_dot_files
cd ~/github/my_dot_files
```
*Note: While some scripts support dynamic paths via `$DOTFILES_ROOT`, keeping it in `~/github/my_dot_files` is currently recommended for maximum compatibility.*

### 2. Configure Secrets
Copy the example configuration file and fill in your private information (API keys, internal IPs, Personal IDs, etc.).
```bash
cp config.example.sh secrets.sh
vim secrets.sh
```
**Important:** `secrets.sh` is git-ignored. Never commit your secrets!

### 3. Install Dependencies & Initialize

#### macOS
Run the initialization script to set up Homebrew, install packages, and link configurations.
```bash
./init_mac.sh
```
This script will:
- Install Homebrew (if not installed)
- Install dependencies from `Brewfile`
- Install Zsh and Oh My Zsh
- Link configuration files

#### Linux (Ubuntu/Debian)
Linux initialization scripts are maintained in the `dev` branch.

### 4. Load Shell Configuration
Add the following line to your `~/.zshrc` or `~/.bashrc` to load the configurations:
```bash
source ~/github/my_dot_files/my_shell_config.sh
```

## 📂 Project Structure

```bash
├── Brewfile                # Homebrew bundle dependencies (macOS)
├── README.md               # Documentation
├── bbs_conf.sh             # BBS shortcuts and specific config
├── common_init_funcs.sh    # Shared functions (installation, config loading)
├── config.example.sh       # Template for secrets & config (Copy to secrets.sh)
├── goto                    # Quick directory jump script
├── init_mac.sh             # macOS initialization script
├── mac_mock_devbox.sh      # Mock env vars for local testing on Mac
├── my_shell_config.sh      # Main shell configuration entry point
├── secrets.sh              # (Ignored) Your private secrets and local config
└── shell/                  # Modular shell configuration
    ├── aliases.sh          # Shell aliases
    ├── exports.sh          # Environment variables
    ├── functions.sh        # Shell functions
    └── paths.sh            # PATH modifications
```

## 🛠 Features & Configurations

### Shell Configuration (`my_shell_config.sh`)
- **Aliases**: Git shortcuts (`gs`, `gc`, `gp`), navigation (`..`, `...`), and utility shorthands.
- **Functions**:
    - `cppc`: Compile C++11 files.
    - `gacp`: Git add, commit, and push in one go.
    - `deepfind`: Recursive grep.
    - `got`: Run specific Go tests with `doas`.
- **Environment**: Sets up `GOPATH`, `PYTHONPATH`, and internal proxy settings.

### Proxy Management (`proxy_toggle.sh`)

`proxy_toggle.sh` toggles the local Xray proxy across three layers in one command: the Xray service (`brew services`), the macOS system proxy (`networksetup`), and the environment variables inherited by GUI-launched apps (`launchctl setenv`). The latter is what lets GUI apps such as Claude Desktop / Cursor and their embedded agents use the proxy, since they don't reliably inherit shell exports or the macOS system proxy.

```bash
./proxy_toggle.sh on      # Start Xray, enable system proxy + launchd proxy env
./proxy_toggle.sh off     # Disable system proxy + launchd proxy env, stop Xray
./proxy_toggle.sh status  # Show system proxy, local port, and launchd proxy state
./proxy_toggle.sh sync    # Reconcile launchd proxy env with the current proxy state
```

With the shell config loaded, the `pt` function (defined in `shell/functions.sh`) wraps the script so it works from any directory: `pt on` / `pt off` / `pt status` / `pt sync`. On top of the script's three layers, `pt on` / `pt off` also applies `xray_proxy` / `noproxy` so the current shell's proxy env vars stay in sync (the script itself is executed, not sourced, so its own exports don't reach your shell).

Ports **must** be set per machine in `secrets.sh` (`XRAY_PROXY_PORT`, `XRAY_SOCKS_PORT`); the hosts default to `127.0.0.1`. There is intentionally no port default: this repo is shared across machines whose xray inbounds differ, and a wrong default silently routes every CLI into a dead socket. Read the real values off the local config:

```bash
jq '.inbounds[] | {protocol, port}' /opt/homebrew/etc/xray/config.json
```

`xray_proxy` exports each endpoint under both lower and upper case (curl reads lowercase; Go and JVM tooling read uppercase), uses `socks5h://` so DNS resolves at the proxy rather than locally, and sets `NODE_USE_ENV_PROXY=1` — without which Node's built-in `fetch` ignores proxy env vars entirely.

Notes:
- **Run it as `./proxy_toggle.sh on`, not `source proxy_toggle.sh on`.**
- **Already-running GUI apps must be fully quit and reopened** to pick up the new proxy environment; macOS cannot change a running process's environment.
- **`launchctl setenv` does not persist across reboot,** while the macOS system proxy does. Each boot therefore starts in a split state: GUI apps stay proxied, CLIs silently go direct. New shells self-heal via `proxy_autoinit` (see below), but the launchd env — which GUI-launched processes inherit — still needs `pt sync` once per boot. `pt status` warns when it detects this split.
- **`proxy_autoinit` in `my_shell_config.sh` restores proxy env on shell start,** but only when xray's HTTP port is actually listening. Keep it conditional: replacing it with a plain `export http_proxy=...` in `.zshrc` would resurrect the proxy in every new terminal after `pt off`, producing a machine whose proxy cannot be turned off. Since `pt off` stops the xray service, a dead port doubles as "the user turned it off"; if `pt off` ever stops halting the service, this needs an explicit state file instead.

### Secrets Management
The project uses `secrets.sh` to manage sensitive data. Define the following in your `secrets.sh`:
- Git User/Email
- API Keys (`TCE_API_KEY`, `METRICS_KEY`)
- Personal IDs (`MY_DID`, `MY_UID`, etc.)

## ❓ Troubleshooting

### 1. `secrets.sh` not found
If you see warnings about missing secrets, ensure you have copied `config.example.sh` to `secrets.sh` and populated it with your values.

### 2. Path issues
If commands are not found, check if `DOTFILES_ROOT` is correctly set. By default it points to `$HOME/github/my_dot_files`. You can override it in your `.zshrc` before sourcing `my_shell_config.sh`.

## 📚 Tutorials
* [程序员内功系列--序篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)
* [程序员内功系列--iTerm与Zsh篇](https://xiaozhou.net/learn-the-command-line-iterm-and-zsh-2017-06-23.html)
* [程序员内功系列--Tmux篇](https://xiaozhou.net/learn-the-command-line-tmux-2018-04-27.html)
* [程序员内功系列–-Vim篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)  
* [程序员内功系列–-常用命令行工具篇](https://xiaozhou.net/learn-the-command-line-tools-md-2018-10-11.html)
