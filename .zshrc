#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Load local zsh settings.
for file in ~/.config/zsh/*.zsh(N); do
  source "$file"
done

# User completions.
fpath=(~/.config/zsh/completion $fpath)
autoload -Uz compinit && compinit -i
