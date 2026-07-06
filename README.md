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
- `.zshrc`, `.zpreztorc`, `.zprofile`, `.zshenv`, `.zlogin`, `.zlogout` - zsh (Prezto) runcoms

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

`make install` runs `prep` (clones Prezto, tpm, and Nord modules) and `deploy`
(symlinks the repo's dotfiles into the home directory) in a single pass.
When `deploy` finds a pre-existing real file where a symlink should go, it moves
that file to `~/.dotfiles_backup/` before linking, so nothing is overwritten
silently.

The zsh runcoms (`.zshrc` etc.) are owned by this repository and symlinked into
the home directory. The Prezto clone at `~/.zprezto` is kept pristine and only
sourced via `init.zsh`, so `make update` can pull upstream changes without
conflicts.

## Make Targets

Run `make help` to list the available targets.

- `prep` - Clone Prezto, tpm, and Nord modules
- `deploy` - Symlink the repo's dotfiles into the home directory
- `install` - Run `prep` and `deploy`
- `update` - Pull updates for the repo and cloned tools
- `clean` - Remove the deployed dotfiles and cloned tools
