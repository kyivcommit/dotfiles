# dotfiles

Portable Oh My Zsh setup for fresh Ubuntu, Debian, and macOS machines.

The installer sets up Oh My Zsh and the plugins listed in `zshrc`, links the
repository config to `~/.zshrc`, and starts a Zsh login shell when run from an
interactive terminal.

## Quick start

Git is required to clone this repository. On a fresh Ubuntu or Debian server:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone git@github.com:kyivcommit/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh install
```

On macOS, Git and Zsh must already be available. If Git is missing, install the
Command Line Tools first with `xcode-select --install`, then run:

```bash
git clone git@github.com:kyivcommit/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh install
```

## Make Zsh the default shell

The installer starts Zsh for the current interactive session only. To use Zsh
automatically on future SSH logins, run this once:

```bash
chsh -s "$(command -v zsh)"
```

Log out and reconnect. Without this step, rerun `install.sh` or use
`exec zsh -l` to start Zsh in the current session.

## Commands

```bash
~/.dotfiles/install.sh install
```

Installs missing Ubuntu/Debian packages, Oh My Zsh, external plugins, and the
shared config. Running it again is safe.

```bash
~/.dotfiles/install.sh update
```

Pulls the latest dotfiles with `--ff-only` and reapplies the installation.

```bash
~/.dotfiles/install.sh update-plugins
```

Updates Oh My Zsh and external plugins with `--ff-only`. Plugins bundled with
Oh My Zsh are skipped.

Running `install.sh` without a command is equivalent to `install`.

## What gets installed

The shared `zshrc` currently enables:

- `git`
- `z`
- `vi-mode`
- `zsh-autosuggestions`
- `fzf-zsh-plugin`
- `zsh-syntax-highlighting`

If an existing `~/.zshrc` is present, the installer moves it to a timestamped
backup before creating the symlink.

## Machine-specific configuration

Keep secrets, local paths, and machine-specific aliases outside the repository:

```bash
cp ~/.dotfiles/zshrc.local.example ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

The shared config loads `~/.zshrc.local` when the file exists. Do not commit
that file.

## Updating machines

After changing and pushing the repository from your main machine, update any
configured server or Mac with:

```bash
~/.dotfiles/install.sh update
```

## fzf first-run message

`fzf-zsh-plugin` may print this message the first time it loads:

```text
Can't find a fzf configuration file at ~/.fzf/fzf.zsh, creating a default one
```

This is expected. The plugin is creating its default configuration. The
installer already starts a fresh shell; use `exec zsh -l` when you need to
reload it manually.

## Tests

Run the portable integration test with:

```bash
./test.sh
```

The test uses temporary directories and fake system commands. It does not
install packages or modify your real shell configuration.
