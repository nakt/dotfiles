# dotfiles

## Deploy

Checkout dotfiles repository

```
# ghq get --shallow https://github.com/nakt/dotfiles
```


Iniitalize & Install base application
```
# cd $HOME/.ghq/github.com/nakt/dotfiles/
# tools/01_init.sh
# pushd ansible && ansible-playbook playbook.yml
# popd
# make install
# make font
```
