#=============== Golang Alias =============================================
alias build="go build ."

#=============== Hexo Alias =============================================
alias hd='hexo g -d'

#=============== Github repos Alias =============================================
alias gt="cd $HOME/github/"
alias dots="cd $HOME/github/my_dot_files"
alias lc="cd $HOME/github/leetcode"
alias resume="cd $HOME/github/MyResume"
alias posts="cd $HOME/github/myblog/blog"

#=============== Git Alias =============================================
alias gs="git status"
alias gs.="git status ."
alias ga='git add'
alias ga.='git add .'
alias gd='git --no-pager diff --word-diff'
alias gd.='git diff .'
alias gf='git fetch'
alias grv='git remote -v'
alias grb='git rebase'
alias grst='git reset'
alias gmd='git commit --amend'
alias gbr='git branch'
alias gpl="git pull"
alias gps="git push"
alias gco="git checkout"
alias gcz="git checkout zmx_dev"
alias gl="git log --oneline --graph --decorate --all"
alias gc="git commit -m"
alias gac="ga . && gc"
alias st="git stash"
alias sta="git stash apply"
alias stp="git stash pop"
alias grhom="git reset --hard origin/master"
alias grmb="git branch | grep -v master | xargs git branch -D "
alias gmm="git merge master"

#--------------- oh-my-zsh 风格补充(与上面别名无冲突的空缺)---------------
# 分支:列出/查看远程/删除/强删
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
# 新建并切换 / 切到主分支(git_main_branch 定义在 functions.sh)
alias gcb='git checkout -b'
alias gcm='git checkout "$(git_main_branch)"'
# diff 暂存区(staged/cached)
alias gds='git diff --staged'
alias gdca='git diff --cached'
# 简洁日志
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
# rebase 交互/续做/中止
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
# push:首推当前分支并设 upstream / 安全强推
alias gpsup='git push --set-upstream origin "$(git_current_branch)"'
alias gpf='git push --force-with-lease'
# stash 列表
alias gstl='git stash list'

#=============== Common Alias =============================================
alias ll='eza -ahl --color=auto'
alias zconf='vim ${DOTFILES_ROOT}/my_shell_config.sh'
alias zload='source ~/.zshrc'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rm -rf"
alias df="df -h"
alias mv="mv -f"
alias slink="ln -s"
alias sed="sed -E"
alias l="ls -l"
alias la="ls -lhAF"
alias cd..="cd .."
alias cd...="cd ../.."
alias cd....="cd ../../.."
alias ...="cd ../.."
alias ....="cd ../../.."

# IDs
alias did='echo -n ${MY_DID} | tee >(pbcopy)'
alias uid='echo -n ${MY_UID} | tee >(pbcopy)'
alias eid='echo -n ${MY_EID} | tee >(pbcopy)'
alias alarmid='echo -n ${MY_ALARMID} | tee >(pbcopy)'
alias fcid='echo -n ${MY_FCID} | tee >(pbcopy)'
alias pnum='echo -n ${MY_PHONE} | tee >(pbcopy)'


#=============== python Alias =============================================
alias python="/usr/bin/python "

#=============== docker Alias =============================================
alias dops="docker ps -a"
alias dorm='docker rm'

#=============== ag Alias =============================================
alias ag='ag --ignore-dir thrift_gen --ignore-dir clients --ignore-dir kitex_gen --ignore-dir pb_gen --ignore-dir ugc_thecat_pyrpc'

#=============== brew Alias =============================================
alias brewdump='brew bundle dump --force --describe'


#=============== SSH 远端开发机 Alias =====================================
# 直接用 Host 名连接对应的远端开发机；ssh -X 开启 X11 转发（便于远端用 xclip 等）。
# test2 / devbox 需在 ~/.ssh/config 里配置为 Host。
alias test2="ssh -X test2"
alias devbox="ssh -X devbox"

#=============== Claude Code Alias =====================================
# 默认带 --chrome 启动，接入 Claude in Chrome 扩展以便直接操控浏览器（仅 mac 有 GUI，dev 分支不加）。
# --effort xhigh + bypass permissions 与 dev 分支语义对齐。
# 同名 alias 不会递归展开，内层 claude 仍解析到 PATH 里的二进制。
alias claude="claude --chrome --effort xhigh --dangerously-skip-permissions"

#=============== Codex Alias =============================================
# 默认以 YOLO 模式启动；同名 alias 不会递归展开。
alias codex='codex --yolo'
