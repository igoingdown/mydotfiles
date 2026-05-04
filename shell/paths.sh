#=============== Base PATH Setting =============================================
# 封装路径设置逻辑
add_to_path() {
    if [ -d "$1" ]; then
        case ":$PATH:" in
            *":$1:"*) ;;
            *) export PATH="$1:$PATH" ;;
        esac
    else
        # echo "Warning: Directory $1 does not exist, skipping."
        :
    fi
}

add_to_path "/usr/local/bin"
add_to_path "/usr/bin"
add_to_path "/bin"
add_to_path "/usr/sbin"
add_to_path "/sbin"
add_to_path "/opt/puppetlabs/bin"
add_to_path "$HOME/bin"
add_to_path "/opt/homebrew/bin"
#add_to_path "$HOME/.cargo/bin"
add_to_path "/opt/homebrew/opt/coreutils/libexec/gnubin"
#add_to_path "/usr/local/texlive/2024basic/bin/universal-darwin"
