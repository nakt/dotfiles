# Local Dotfiles
DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*)
EXCLUSIONS := .git .gitmodules %.swp
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

# prezto Settings
PREZTO_PATH := ~/.zprezto
PREZTO_CANDIDATES := $(wildcard $(PREZTO_PATH)/runcoms/??*)
PREZTO_EXCLUSIONS := README.md .git .swp
PREZTO_DOTFILES   := $(filter-out %$(PREZTO_EXCLUSIONS), $(PREZTO_CANDIDATES))

# Nord
NORD_DIRCOLORS_PATH := $(DOTPATH)/modules/nord-dircolors
NORD_DIRCOLORS_DOTFILES := $(wildcard $(NORD_DIRCOLORS_PATH)/src/??*)

# tmux Settings
TPM_PATH := ~/.tmux/plugins/tpm

.PHONY: all prep update deploy setting install font clean

all:

prep:
	[ -d $(PREZTO_PATH) ] || git clone --recursive --depth 1 https://github.com/sorin-ionescu/prezto.git $(PREZTO_PATH)
	[ -d $(TPM_PATH) ] || git clone --depth 1 https://github.com/tmux-plugins/tpm $(TPM_PATH)
	[ -d $(NORD_DIRCOLORS_PATH) ] || git clone --depth 1 https://github.com/arcticicestudio/nord-dircolors $(NORD_DIRCOLORS_PATH)

update:
	@ git pull origin master
	@ git submodule update --init --recursive
	@ git -C $(PREZTO_PATH) pull
	@ git -C $(PREZTO_PATH) submodule update --init --recursive

deploy:
	@ $(foreach val, $(DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)
	@ $(foreach val, $(PREZTO_DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/.$(notdir $(val));)
	@ $(foreach val, $(NORD_DIRCOLORS_DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/.$(notdir $(val));)

setting:
	@ DOTPATH=$(DOTPATH) bash $(DOTPATH)/tools/02_zsh.sh

install: prep deploy setting
	@ exec $$SHELL

font:
	@ DOTPATH=$(DOTPATH) bash $(DOTPATH)/tools/10_font.sh

clean:
	@ echo 'Remove dot files...'
	@ $(foreach val, $(DOTFILES), rm -vrf $(HOME)/$(val);)
	rm -rf $(PREZTO_PATH)
	rm -f $(HOME)/.zlogin $(HOME)/.zlogout $(HOME)/.zpreztorc $(HOME)/.zprofile $(HOME)/.zshenv $(HOME)/.zshrc

