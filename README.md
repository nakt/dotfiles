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

<!-- START makefile-doc -->
```
$ make help 
clean                          Cleanup all configuration and tools
deploy                         Create symboric link to home directory
font                           Install powerline font
install                        Execute prep, deploy, setting
prep                           Prepare tools before setup
setting                        Execute optional setup script
update                         Update all tools 
```
<!-- END makefile-doc -->
