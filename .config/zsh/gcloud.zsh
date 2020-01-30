
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/opt/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/opt/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/google-cloud-sdk/completion.zsh.inc'; fi

function gconf() {

  projData=$(gcloud config configurations list | peco)

  if echo "${projData}" | grep -E "^[a-zA-Z].*" > /dev/null ; then

    config=$(echo ${projData} | awk '{print $1}')

    gcloud config configurations activate ${config}



    echo "=== The current account is as follows ==="

    gcloud config configurations list | grep "${config}"

  fi

}
