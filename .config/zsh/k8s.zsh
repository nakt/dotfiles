if which kubectl >/dev/null 2>&1 ; then
  alias k='kubectl'
  source <(kubectl completion zsh)
fi

