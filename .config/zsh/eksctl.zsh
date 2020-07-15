if which eksctl >/dev/null 2>&1 ; then
  eval "$(eksctl completion zsh)"
else
  echo "Not installed: docker-compose"
fi
