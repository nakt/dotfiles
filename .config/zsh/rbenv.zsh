if which rbenv >/dev/null 2>&1 ; then
  eval "$(rbenv init - zsh)"
else
  echo "Not installed: rbenv"
fi

