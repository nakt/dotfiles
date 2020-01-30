if which docker-compose >/dev/null 2>&1 ; then
  alias dc='docker-compose'
else
  echo "Not installed: docker-compose"
fi
