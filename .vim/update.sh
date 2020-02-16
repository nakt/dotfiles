for sub in $(ls -d plugged/*); do pushd ${sub} && git pull && popd ; done
