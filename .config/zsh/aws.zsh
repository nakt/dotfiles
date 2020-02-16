if ! which complete >/dev/null 2>&1 ; then
  autoload -U +X bashcompinit && bashcompinit
  autoload -U +X compinit && compinit
fi
complete -C $(which aws_completer) aws
