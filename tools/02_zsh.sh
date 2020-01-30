#!/bin/bash

SEC_ZSH="### zsh local setting"

check_current_sec_zsh=$(grep -c "${SEC_ZSH}" ~/.zshrc 2> /dev/null)
if [ "${check_current_sec_zsh}" = "0" ]; then
  echo "Add zshrc local setting to ~/.zshrc"
cat <<EOD >> ~/.zshrc
${SEC_ZSH}
for file in ~/.config/zsh/*.zsh; do source "\${file}"; done
${SEC_ZSH}
EOD
fi
