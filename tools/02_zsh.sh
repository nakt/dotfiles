#!/bin/bash

set -euo pipefail

ZSH_COMPLETION_DIR="${HOME}/.zsh/completion"
ZSHRC_FILE="${HOME}/.zshrc"
SEC_ZSH="### zsh local setting"

# Create completion directory if it doesn't exist
if [ ! -d "${ZSH_COMPLETION_DIR}" ]; then
  echo "Creating directory for zsh completion files at ${ZSH_COMPLETION_DIR}"
  mkdir -p "${ZSH_COMPLETION_DIR}"
fi

# Check if zshrc already contains the section
if ! grep -q "${SEC_ZSH}" "${ZSHRC_FILE}" 2>/dev/null; then
  echo "Adding local zsh settings to ${ZSHRC_FILE}"
  cat <<EOF >> "${ZSHRC_FILE}"
${SEC_ZSH}
for file in ~/.config/zsh/*.zsh; do source "\${file}"; done
fpath=(~/.zsh/completion \$fpath)
autoload -Uz compinit && compinit -i
${SEC_ZSH}
EOF
else
  echo "Local zsh setting already present in ${ZSHRC_FILE}, skipping"
fi