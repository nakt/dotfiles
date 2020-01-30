if which direnv >/dev/null 2>&1 ; then
  eval "$(direnv hook zsh)"
else
  echo "Not installed: direnv"
fi

