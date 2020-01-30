export PATH=$PATH:$HOME/.pulumi/bin

if which pulumi >/dev/null 2>&1 ; then
  alias pm='pulumi'
fi

