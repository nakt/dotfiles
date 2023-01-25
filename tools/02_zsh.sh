#!/bin/bash

SEC_ZSH="### zsh local setting"

if [ ! -d ~/.zsh/completion ]; then
  echo "Create directory for zsh completion file"
  mkdir -p ~/.zsh/completion
fi

check_current_sec_zsh=$(grep -c "${SEC_ZSH}" ~/.zshrc 2> /dev/null)
if [ "${check_current_sec_zsh}" = "0" ]; then
  echo "Add zshrc local setting to ~/.zshrc"
cat <<EOD >> ~/.zshrc
${SEC_ZSH}
for file in ~/.config/zsh/*.zsh; do source "\${file}"; done
fpath=(~/.zsh/completion $fpath)
autoload -Uz compinit && compinit -i
${SEC_ZSH}
EOD
fi
