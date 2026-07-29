# dotfiles

Personal dotfiles repository for managing shell, editor, and development tool configurations.

## Managed Dotfiles

Deployed to the home directory by `make deploy`. The `DOTFILES` variable in the
`Makefile` is the authoritative list; entries are opt-in, so a file placed in the
repository root is not deployed until it is named there.

- `.claude/` - Claude Code configuration
- `.codex/` - Codex configuration
- `.config/` - XDG configuration directory
- `.gemini/` - Gemini CLI configuration
- `.gitconfig` - Git configuration
- `.gitignore` - Global git ignore patterns (referenced by `core.excludesfile`)
- `.npmrc` - npm configuration
- `.tmux.conf` - tmux configuration
- `.vim/` - Vim configuration directory
- `.vimrc` - Vim configuration file
- `.zshrc` - zsh runcom (sources Prezto and `~/.config/zsh/*.zsh`)

`.pre-commit-config.yaml` configures this repository's own pre-commit hooks and
is not deployed: pre-commit only reads the config at the root of the repository
being committed to, so a copy in the home directory is never consulted.

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

## Make Targets

Run `make help` to list the available targets.

- `prep` - Clone Prezto, tpm, and Nord modules
- `deploy` - Symlink the repo's dotfiles into the home directory
- `install` - Run `prep` and `deploy`
- `update` - Pull updates for the repo and cloned tools
- `clean` - Remove the deployed dotfiles and cloned tools
