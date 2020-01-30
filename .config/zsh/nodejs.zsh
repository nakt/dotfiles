node_path="${HOME}/.nodebrew/current/bin"

if [ -e ${node_path} ]; then
  PATH="${node_path}:$PATH"
else
  echo "Not installed: nodejs w/ nodebrew"
fi
