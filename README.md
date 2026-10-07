# dotfiles

Portable Oh My Zsh setup for fresh Ubuntu, Debian, and macOS machines.

The installer sets up Oh My Zsh and the plugins listed in `zsh/.zshrc`, links
every package into `~` with [GNU Stow](https://www.gnu.org/software/stow/), and
starts a Zsh login shell when run from an interactive terminal.

## Layout

Each top-level directory is a Stow package that mirrors `~`. For example,
`zsh/.zshrc` is linked as `~/.zshrc` and `nvim/.config/nvim/init.lua` as
`~/.config/nvim/init.lua`. `zsh/.zshenv` sets `EDITOR`/`VISUAL`, which every
shell reads (including non-interactive ones such as cron or `ssh host cmd`);
the rest of the shell setup lives in `.zshrc`.

| Package   | Links                                  |
|-----------|----------------------------------------|
| `zsh`     | `~/.zshrc`, `~/.zshenv`                |
| `nvim`    | `~/.config/nvim` (LazyVim)             |
| `yazi`    | `~/.config/yazi/*.toml`, `init.lua`    |

Stow runs with `--no-folding`, so it links individual files and keeps real
directories. Files that apps write next to the config, such as plugins, logs,
or sessions, stay out of the repository — except LazyVim's `lazy-lock.json`,
which is tracked so every machine gets the same plugin pins. Lazy rewrites it
locally whenever plugins change, so `install.sh update` discards that local
churn before pulling: the repository pins always win and Lazy syncs the
plugins on the next start.

On Ubuntu/Debian machines with a desktop session, the installer also downloads
FiraCode Nerd Font Mono into `~/.local/share/fonts`. Restart the terminal to
see the icons. SSH-only servers skip the font, because the terminal on the
connecting machine draws the icons.

LazyVim needs a recent Neovim (0.11.2 or newer). On Ubuntu/Debian the installer
replaces an older or missing `nvim` with the upstream release in
`~/.local/opt/nvim`, linked as `~/.local/bin/nvim`. Any other `nvim` in `PATH`
is left in place; `~/.local/bin` comes first in `PATH` after the shell restarts.

Yazi is not in apt, so on Ubuntu/Debian the installer downloads the upstream
release (x86_64 or aarch64) into `~/.local/bin`. Yazi plugins and flavors are
not committed; the installer fetches them from `package.toml` with
`ya pkg install`.

To add a package, create the files inside the repository and link them:

```bash
mkdir -p ~/.dotfiles/tmux/.config/tmux
$EDITOR ~/.dotfiles/tmux/.config/tmux/tmux.conf
stow --dir ~/.dotfiles --target ~ --no-folding --restow tmux
```

To move an existing config into a package, `mv` it into the package directory
first. Use `stow --dir ~/.dotfiles --target ~ -D tmux` to remove the links.

Some apps replace a symlinked file with a regular file when they save, which
breaks the link (Karabiner-Elements does this with `karabiner.json`). Put an
empty `.stow-fold` file in the root of such a package and Stow links the whole
directory instead. Move any existing directory aside before the first run, and
add a `.gitignore` for files the app writes there.

## Extra packages

Set `DOTFILES_EXTRA_DIR` to a second directory of Stow packages, for example a
private repository with machine-specific configs. `install.sh` links its
packages together with the ones in this repository.

## Quick start

Git is required to clone this repository. On a fresh Ubuntu or Debian server:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/kyivcommit/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh install
```

On macOS, Git and Zsh must already be available. Homebrew is needed if `stow`,
`bat`, `nvim`, `zoxide`, or `yazi` is missing. If Git is missing, install the Command Line Tools first with
`xcode-select --install`, then run:

```bash
git clone https://github.com/kyivcommit/dotfiles.git ~/.dotfiles
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

Installs missing Ubuntu/Debian packages, `stow`, `bat`, a current `nvim`, `zoxide`, `yazi`, Oh My Zsh,
external plugins, and the shared config. On Ubuntu/Debian, the installer links `batcat` as
`~/.local/bin/bat`; the shared `zsh/.zshrc` already adds that directory to `PATH`.
On macOS, it installs missing `stow`, `bat`, `nvim`, `zoxide`, and `yazi` through Homebrew. Running it
again is safe.

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

The shared `zsh/.zshrc` currently enables:

- `git`
- `zsh-autosuggestions`
- `fzf-zsh-plugin`
- `zsh-syntax-highlighting`

If a config file already exists and is not linked to this repository, the
installer moves it to a timestamped backup before Stow creates the symlink.

## Machine-specific configuration

Keep secrets, local paths, and machine-specific aliases outside the repository:

```bash
cp ~/.dotfiles/zshrc.local.example ~/.zshrc.local
chmod 600 ~/.zshrc.local
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
