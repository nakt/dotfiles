if which docker-compose >/dev/null 2>&1 ; then
  alias dc='docker-compose'
  if [ ! -f ~/.zsh/completion/_docker-compose ]; then
    ln -s /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ~/.zsh/completion/_docker
    ln -s /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ~/.zsh/completion/_docker-compose
  fi

else
  echo "Not installed: docker-compose"
fi
