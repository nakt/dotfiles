# dotfiles

Personal dotfiles repository for managing shell, editor, and development tool configurations.

## Managed Dotfiles

- `.claude/` - Claude configuration
- `.config/` - Configuration directory
- `.gitconfig` - Git configuration
- `.gitignore` - Git ignore patterns
- `.pre-commit-config.yaml` - Pre-commit hook configuration
- `.tmux.conf` - tmux configuration
- `.vim/` - Vim configuration directory
- `.vimrc` - Vim configuration file

## Setup Instructions

### 1. Install Developer Tools

```bash
xcode-select --install
```

### 2. Clone Repository

```bash
git clone --depth 1 https://github.com/nakt/dotfiles ~/repos/github.com/nakt/dotfiles
cd ~/repos/github.com/nakt/dotfiles
```

### 3. Initialize and Install Applications

```bash
# Install Homebrew and ansible
tools/01_init.sh

# Install packages via ansible
cd ansible && ansible-playbook playbook.yml
cd ..

# Deploy dotfiles and configure
make install
```

<!-- START makefile-doc -->
```text
$ make help
clean                          Cleanup all configuration and tools
deploy                         Create symbolic link to home directory
install                        Execute prep, deploy, setting
prep                           Prepare tools before setup
setting                        Execute optional setup script
update                         Update all tools
```
<!-- END makefile-doc -->