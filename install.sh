#!/usr/bin/env bash
set -eu

dotfiles_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
dotfiles_home=${DOTFILES_HOME:-$HOME}
zsh_config="$dotfiles_dir/zshrc"
oh_my_zsh_dir="$dotfiles_home/.oh-my-zsh"
custom_plugins_dir="$oh_my_zsh_dir/custom/plugins"

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [install|update|update-plugins]

  install         Install dependencies, Oh My Zsh, plugins, and config.
  update          Pull dotfiles with --ff-only, then apply them.
  update-plugins  Update Oh My Zsh and external plugins with --ff-only.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

run_apt() {
  if [ "$(id -u)" -eq 0 ]; then
    apt-get "$@"
  else
    require_command sudo
    sudo apt-get "$@"
  fi
}

install_dependencies() {
  case "$(uname -s)" in
    Linux)
      require_command apt-get
      apt_updated=false
      if ! command -v dpkg-query >/dev/null 2>&1 \
        || ! dpkg-query -W zsh git ca-certificates >/dev/null 2>&1; then
        run_apt update
        apt_updated=true
        run_apt install -y zsh git ca-certificates
      fi
      if ! command -v bat >/dev/null 2>&1 \
        && [ ! -x "$dotfiles_home/.local/bin/bat" ]; then
        if ! command -v batcat >/dev/null 2>&1; then
          if [ "$apt_updated" = false ]; then
            run_apt update
            apt_updated=true
          fi
          run_apt install -y bat
        fi
        require_command batcat
        mkdir -p "$dotfiles_home/.local/bin"
        if [ -e "$dotfiles_home/.local/bin/bat" ] \
          || [ -L "$dotfiles_home/.local/bin/bat" ]; then
          fail "$dotfiles_home/.local/bin/bat exists but is not executable"
        fi
        ln -s "$(command -v batcat)" "$dotfiles_home/.local/bin/bat"
      fi
      if ! command -v nvim >/dev/null 2>&1; then
        if [ "$apt_updated" = false ]; then
          run_apt update
        fi
        run_apt install -y neovim
        require_command nvim
      fi
      ;;
    Darwin)
      if ! command -v bat >/dev/null 2>&1 \
        && [ ! -x "$dotfiles_home/.local/bin/bat" ]; then
        require_command brew
        brew install bat
        require_command bat
      fi
      if ! command -v nvim >/dev/null 2>&1; then
        require_command brew
        brew install neovim
        require_command nvim
      fi
      ;;
    *)
      fail "supported operating systems: Ubuntu, Debian, macOS"
      ;;
  esac

  require_command git
  require_command zsh
}

plugin_url() {
  case "$1" in
    zsh-autosuggestions)
      printf '%s\n' 'https://github.com/zsh-users/zsh-autosuggestions.git'
      ;;
    zsh-syntax-highlighting)
      printf '%s\n' 'https://github.com/zsh-users/zsh-syntax-highlighting.git'
      ;;
    fzf-zsh-plugin)
      printf '%s\n' 'https://github.com/unixorn/fzf-zsh-plugin.git'
      ;;
    *)
      return 1
      ;;
  esac
}

read_plugins() {
  awk '
    function emit(line, closes, count, position, words) {
      sub(/#.*/, "", line)
      closes = index(line, ")")
      sub(/\).*/, "", line)
      count = split(line, words, /[[:space:]]+/)
      for (position = 1; position <= count; position++) {
        if (words[position] != "") print words[position]
      }
      if (closes) exit
    }

    /^[[:space:]]*plugins[[:space:]]*=\(/ {
      found = 1
      line = $0
      sub(/^[^(]*\(/, "", line)
      emit(line)
      next
    }

    found { emit($0) }

    END { if (!found) exit 2 }
  ' "$zsh_config"
}

ensure_checkout() {
  checkout_url=$1
  checkout_path=$2

  if [ -d "$checkout_path/.git" ]; then
    return
  fi

  if [ -e "$checkout_path" ] || [ -L "$checkout_path" ]; then
    fail "$checkout_path exists but is not a Git checkout"
  fi

  git clone --depth 1 "$checkout_url" "$checkout_path"
}

ensure_plugins() {
  [ -f "$zsh_config" ] || fail "$zsh_config is missing"

  ensure_checkout 'https://github.com/ohmyzsh/ohmyzsh.git' "$oh_my_zsh_dir"
  mkdir -p "$custom_plugins_dir"

  plugin_names=$(read_plugins) || fail "cannot read plugins=(...) from $zsh_config"
  [ -n "$plugin_names" ] || fail "plugins=(...) is empty in $zsh_config"

  for plugin_name in $plugin_names; do
    case "$plugin_name" in
      *[!A-Za-z0-9._-]*|'')
        fail "invalid plugin name in $zsh_config: $plugin_name"
        ;;
    esac

    if [ -d "$oh_my_zsh_dir/plugins/$plugin_name" ]; then
      continue
    fi

    plugin_path="$custom_plugins_dir/$plugin_name"
    if [ -d "$plugin_path/.git" ]; then
      continue
    fi

    if plugin_origin=$(plugin_url "$plugin_name"); then
      ensure_checkout "$plugin_origin" "$plugin_path"
    else
      fail "no repository configured for external plugin: $plugin_name"
    fi
  done
}

apply_config() {
  config_target="$dotfiles_home/.zshrc"

  if [ -L "$config_target" ] \
    && [ "$(readlink "$config_target")" = "$zsh_config" ]; then
    return
  fi

  if [ -e "$config_target" ] || [ -L "$config_target" ]; then
    backup_path="$config_target.backup.$(date +%Y%m%d%H%M%S)"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
      backup_path="$backup_path.$$"
    fi
    mv "$config_target" "$backup_path"
    say "Backed up existing config: $backup_path"
  fi

  ln -s "$zsh_config" "$config_target"
  say "Linked config: $config_target -> $zsh_config"
}

install_all() {
  install_dependencies
  ensure_plugins
  apply_config
}

update_checkout() {
  [ -d "$1/.git" ] || fail "$1 is not a Git checkout"
  git -C "$1" pull --ff-only
}

update_plugins() {
  install_all
  update_checkout "$oh_my_zsh_dir"

  plugin_names=$(read_plugins)
  for plugin_name in $plugin_names; do
    if [ -d "$oh_my_zsh_dir/plugins/$plugin_name" ]; then
      continue
    fi
    if plugin_url "$plugin_name" >/dev/null 2>&1; then
      update_checkout "$custom_plugins_dir/$plugin_name"
    fi
  done
}

case "$dotfiles_home" in
  /*) ;;
  *) fail "DOTFILES_HOME must be an absolute path" ;;
esac

command_name=${1:-install}
[ "$#" -le 1 ] || { usage >&2; exit 2; }

case "$command_name" in
  install)
    install_all
    ;;
  update)
    require_command git
    git -C "$dotfiles_dir" pull --ff-only
    exec "$dotfiles_dir/install.sh" install
    ;;
  update-plugins)
    update_plugins
    ;;
  help|-h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

zsh_path=$(command -v zsh)
if [ "${SHELL:-}" != "$zsh_path" ]; then
  say "Optional default shell: chsh -s $zsh_path"
fi

if [ -t 0 ] && [ -t 1 ]; then
  say "Starting login shell: $zsh_path"
  exec "$zsh_path" -l
fi

say "Ready. Start manually: exec $zsh_path -l"
