.DEFAULT_GOAL := help

# Local Dotfiles
# Deploy targets are listed explicitly rather than globbed. A glob over the
# repository root leaks anything that happens to land there (.DS_Store, build
# leftovers, ignored scratch directories) into $HOME; adding a dotfile here is
# the opt-in step.
DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
DOTFILES   := \
	.claude \
	.codex \
	.config \
	.gemini \
	.gitconfig \
	.gitignore \
	.npmrc \
	.tmux.conf \
	.vim \
	.vimrc \
	.zshrc
BACKUP_DIR := $(HOME)/.dotfiles_backup

# prezto Settings
# .zshrc is repo-owned (linked via DOTFILES); the other runcoms are symlinked
# from the pristine Prezto clone by the deploy target.
PREZTO_PATH := ~/.zprezto
PREZTO_RUNCOMS := zlogin zlogout zpreztorc zprofile zshenv

# Nord
NORD_DIRCOLORS_PATH := $(DOTPATH)/modules/nord-dircolors
NORD_ITERM2_PATH := $(DOTPATH)/modules/nord-iterm2

# tmux Settings
TPM_PATH := ~/.tmux/plugins/tpm

.PHONY: all prep update deploy install clean help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

prep: ## Prepare tools before setup
	[ -d $(PREZTO_PATH) ] || git clone --recursive --depth 1 https://github.com/sorin-ionescu/prezto.git $(PREZTO_PATH)
	[ -d $(TPM_PATH) ] || git clone --depth 1 https://github.com/tmux-plugins/tpm $(TPM_PATH)
	[ -d $(NORD_DIRCOLORS_PATH) ] || git clone --depth 1 https://github.com/arcticicestudio/nord-dircolors $(NORD_DIRCOLORS_PATH)
	[ -d $(NORD_ITERM2_PATH) ] || git clone --depth 1 https://github.com/nordtheme/iterm2 $(NORD_ITERM2_PATH)

update: ## Update all tools
	@ git pull origin main
	@ git -C $(PREZTO_PATH) pull
	@ git -C $(PREZTO_PATH) submodule update --init --recursive
	@ git -C $(TPM_PATH) pull
	@ git -C $(NORD_DIRCOLORS_PATH) pull
	@ git -C $(NORD_ITERM2_PATH) pull

deploy: ## Create symbolic link to home directory
	@ for val in $(DOTFILES) .dir_colors $(addprefix .,$(PREZTO_RUNCOMS)); do \
	    dst=$(HOME)/$$val; \
	    if [ -e "$$dst" ] && [ ! -L "$$dst" ]; then \
	      mkdir -p $(BACKUP_DIR); \
	      echo "backup existing $$dst -> $(BACKUP_DIR)/"; \
	      mv "$$dst" $(BACKUP_DIR)/; \
	    fi; \
	  done
	@ $(foreach val, $(DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)
	@ ln -sfnv $(NORD_DIRCOLORS_PATH)/src/dir_colors $(HOME)/.dir_colors
	@ $(foreach val, $(PREZTO_RUNCOMS), ln -sfnv $(PREZTO_PATH)/runcoms/$(val) $(HOME)/.$(val);)

install: prep deploy ## Execute prep, deploy
	@ exec $$SHELL

clean: ## Cleanup all configuration and tools
	@ echo 'Remove dot files...'
	@ $(foreach val, $(DOTFILES), rm -vrf $(HOME)/$(val);)
	@ $(foreach val, $(PREZTO_RUNCOMS), rm -vf $(HOME)/.$(val);)
	rm -rf $(PREZTO_PATH)
	rm -f ${HOME}/.dir_colors
