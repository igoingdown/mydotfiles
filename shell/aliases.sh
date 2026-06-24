#=============== Golang Alias =============================================
alias build="go build ."

#=============== Hexo Alias =============================================
alias hd='hexo g -d'

#=============== Tmux Alias =============================================
alias tma="tmux a"
alias tx="tmux"

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
alias gpl="git pull -p"
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

#=============== Common Alias =============================================
if command -v eza >/dev/null 2>&1; then
    alias ll='eza -ahl --color=auto'
else
    alias ll='ls -alh'
fi
alias zconf='vim ${DOTFILES_ROOT}/my_shell_config.sh'
alias zload='source ~/.bashrc'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rm -rf"
alias df="df -h"
alias mv="mv -i"
alias slink="link -s"
alias sed="sed -E"
alias l="ls -l"
alias la="ls -lhAF"
alias cd..="cd .."
alias cd...="cd ../.."
alias cd....="cd ../../.."
alias ...="cd ../.."
alias ....="cd ../../.."

# IDs
alias did="echo -n ${MY_DID} | tee >(pbcopy)"
alias uid="echo -n ${MY_UID} | tee >(pbcopy)"
alias eid="echo -n ${MY_EID} | tee >(pbcopy)"
alias alarmid="echo -n ${MY_ALARMID} | tee >(pbcopy)"
alias fcid="echo -n ${MY_FCID} | tee >(pbcopy)"
alias pnum="echo -n ${MY_PHONE} | tee >(pbcopy)"

#=============== docker Alias =============================================
alias dops="docker ps -a"
alias dorm='docker rm'

#=============== brew Alias =============================================
alias brewdump='brew bundle dump --force --describe'

#=============== Claude Code Alias =============================================
alias claude='claude --effort xhigh --dangerously-skip-permissions'
