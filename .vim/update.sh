for sub in $(gls -d plugged); do pushd ${sub} && git pull && popd ; done
