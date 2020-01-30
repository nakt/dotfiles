tfenv_path="$HOME/.ghq/github.com/tfutils/tfenv/bin"

if [ -e ${tfenv_path} ]; then
  PATH="${tfenv_path}:$PATH"
fi
