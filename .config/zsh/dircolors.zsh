if [ -f ~/.dir_colors ]; then
  if type dircolors > /dev/null 2>&1; then
    eval $(dircolors ~/.dir_colors)
  elif type gdircolors > /dev/null 2>&1; then
    eval $(gdircolors ~/.dir_colors)
  fi
  zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
fi
