# dotfiles

## Deploy

Checkout dotfiles repository

```
# GHQ_ROOT=~/repos ghq get --shallow https://github.com/nakt/dotfiles
```

Iniitalize & Install base application
```
# cd $HOME/ghq/github.com/nakt/dotfiles/
# tools/01_init.sh
# pushd ansible && ansible-playbook playbook.yml
# popd
# make install
```

<!-- START makefile-doc -->
```
$ make help
clean                          Cleanup all configuration and tools
deploy                         Create symbolic link to home directory
install                        Execute prep, deploy, setting
prep                           Prepare tools before setup
setting                        Execute optional setup script
update                         Update all tools
```
<!-- END makefile-doc -->