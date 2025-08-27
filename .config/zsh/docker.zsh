# Zsh only: safer shell options
setopt NO_NOMATCH

ZSH_COMPLETION_DIR="$HOME/.zsh/completion"

# Ensure completion directory exists
mkdir -p "$ZSH_COMPLETION_DIR"

# Prefer 'docker compose' over deprecated 'docker-compose'
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then

  # Link completion files if not already present
  [[ -f "$ZSH_COMPLETION_DIR/_docker" ]] || \
    ln -s /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion "$ZSH_COMPLETION_DIR/_docker" && \

  [[ -f "$ZSH_COMPLETION_DIR/_docker-compose" ]] || \
    ln -s /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion "$ZSH_COMPLETION_DIR/_docker-compose" && \

else
  echo "Docker with Compose plugin is not installed or not functional"
fi