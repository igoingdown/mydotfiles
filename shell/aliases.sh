#=============== Golang Alias =============================================
alias build="go build ."

#=============== Dev machine Alias =============================================
alias odev="ssh $DEV_USER_NAME@$ONLINE_DEV_IP"
alias dev="ssh $DEV_USER_NAME@$DEV_IP"
alias ndev="ssh $DEV_USER_NAME@$NEW_DEV_IP"

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

#=============== Common Alias =============================================
alias ll='eza -ahl --color=auto'
alias zconf='vim ${DOTFILES_ROOT}/my_shell_config.sh'
alias zload='source ~/.zshrc'
alias ssh="ssh -X"
alias md="mkdir -p"
alias rd="rm -rf"
alias df="df -h"
alias mv="mv -f"
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


#=============== python Alias =============================================
alias python="/usr/bin/python "

#=============== docker Alias =============================================
alias dops="docker ps -a"
alias dorm='docker rm'

#=============== ag Alias =============================================
alias ag='ag --ignore-dir thrift_gen --ignore-dir clients --ignore-dir kitex_gen --ignore-dir pb_gen --ignore-dir ugc_thecat_pyrpc'

#=============== ppe Alias =============================================
alias ppe=jump_ppe_by_psm
