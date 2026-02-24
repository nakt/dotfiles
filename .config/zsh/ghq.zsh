if [[ -d /Volumes/Data/repos ]]; then
  export GHQ_ROOT=/Volumes/Data/repos
else
  export GHQ_ROOT="$HOME/repos"
fi

function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^g' peco-src
