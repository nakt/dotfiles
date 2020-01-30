export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH

if which go >/dev/null 2>&1 ; then
  export GOROOT=$( go env GOROOT )
else
  echo "Not installed: go"
fi
