alias '..'='cd ..'
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g G='| grep'
alias -g T='| tail'
alias ls='ls --color=auto'
alias strip_color='sed "s/\x1b\[[0-9;]*m//g"'

if which pbcopy >/dev/null 2>&1 ; then
  alias -g C='| pbcopy'
elif which xsel >/dev/null 2>&1 ; then
  alias -g C='| xsel --input --clipboard'
elif which clip.exe >/dev/null 2>&1 ; then
  alias -g C='| clip.exe 2> /dev/null'
fi

alias g='cd $(ghq root)/$(ghq list | peco)'
