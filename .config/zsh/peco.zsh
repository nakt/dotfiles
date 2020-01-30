function peco-history-selection() {
    BUFFER=`history -n 1 | tail -n 100 | sort | uniq | awk '!a[$0]++' | peco`
    CURSOR=$#BUFFER
    zle reset-prompt
}

zle -N peco-history-selection
bindkey '^R' peco-history-selection


