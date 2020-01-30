DEFAULT_ENV_PATH="$HOME/.venv/default/bin/activate"

if [ -e ${DEFAULT_ENV_PATH} ]; then
  source $HOME/.venv/default/bin/activate
else
  echo "Couldn't find defautl virtualenv"
fi
