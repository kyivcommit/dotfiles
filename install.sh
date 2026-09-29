#!/usr/bin/env bash
set -eu

dotfiles_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
dotfiles_home=${DOTFILES_HOME:-$HOME}
zsh_config="$dotfiles_dir/zsh/.zshrc"
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

# LazyVim needs a recent Neovim; apt ships an older one, so Linux gets the
# upstream release in ~/.local/opt/nvim.
nvim_min_version=0.11.2

nvim_is_current() {
  [ -n "${1:-}" ] || return 1
  nvim_found=$("$1" --version 2>/dev/null | sed -n '1s/^NVIM v//p')
  [ -n "$nvim_found" ] || return 1
  [ "$(printf '%s\n%s\n' "$nvim_min_version" "$nvim_found" | sort -V | head -n 1)" = "$nvim_min_version" ]
}

install_nvim_release() {
  if nvim_is_current "$dotfiles_home/.local/bin/nvim" \
    || nvim_is_current "$(command -v nvim || true)"; then
    return
  fi

  case "$(uname -m)" in
    x86_64) nvim_target=nvim-linux-x86_64 ;;
    aarch64|arm64) nvim_target=nvim-linux-arm64 ;;
    *) fail "no Neovim release for architecture: $(uname -m)" ;;
  esac
  nvim_tmp=$(mktemp -d "${TMPDIR:-/tmp}/nvim.XXXXXX")

  curl -fsSL -o "$nvim_tmp/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/$nvim_target.tar.gz"
  tar -xzf "$nvim_tmp/nvim.tar.gz" -C "$nvim_tmp"
  mkdir -p "$dotfiles_home/.local/opt" "$dotfiles_home/.local/bin"
  rm -rf "$dotfiles_home/.local/opt/nvim"
  mv "$nvim_tmp/$nvim_target" "$dotfiles_home/.local/opt/nvim"
  ln -sf ../opt/nvim/bin/nvim "$dotfiles_home/.local/bin/nvim"
  rm -rf "$nvim_tmp"
}

# yazi is not in apt, so Linux gets the upstream release in ~/.local/bin.
install_yazi_release() {
  if command -v yazi >/dev/null 2>&1 \
    || [ -x "$dotfiles_home/.local/bin/yazi" ]; then
    return
  fi

  case "$(uname -m)" in
    x86_64) yazi_arch=x86_64 ;;
    aarch64|arm64) yazi_arch=aarch64 ;;
    *) fail "no yazi release for architecture: $(uname -m)" ;;
  esac
  yazi_target="yazi-$yazi_arch-unknown-linux-gnu"
  yazi_tmp=$(mktemp -d "${TMPDIR:-/tmp}/yazi.XXXXXX")

  curl -fsSL -o "$yazi_tmp/yazi.zip" \
    "https://github.com/sxyazi/yazi/releases/latest/download/$yazi_target.zip"
  unzip -q "$yazi_tmp/yazi.zip" -d "$yazi_tmp"
  mkdir -p "$dotfiles_home/.local/bin"
  install -m 755 "$yazi_tmp/$yazi_target/yazi" "$yazi_tmp/$yazi_target/ya" \
    "$dotfiles_home/.local/bin/"
  rm -rf "$yazi_tmp"
}

# Terminal icons come from the machine that draws the terminal, so fonts are
# only needed where a desktop session exists (not on SSH-only servers).
install_nerd_font() {
  share_dir=${DOTFILES_SHARE_DIR:-/usr/share}
  font_dir="$dotfiles_home/.local/share/fonts/FiraCodeNerdFont"

  if [ ! -d "$share_dir/xsessions" ] && [ ! -d "$share_dir/wayland-sessions" ]; then
    return
  fi
  if [ -f "$font_dir/FiraCodeNerdFontMono-Regular.ttf" ]; then
    return
  fi

  font_tmp=$(mktemp -d "${TMPDIR:-/tmp}/font.XXXXXX")
  curl -fsSL -o "$font_tmp/FiraCode.zip" \
    'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip'
  mkdir -p "$font_dir"
  unzip -q -o "$font_tmp/FiraCode.zip" 'FiraCodeNerdFontMono-*.ttf' -d "$font_dir"
  rm -rf "$font_tmp"
  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_dir"
  fi
}

# Plugins and flavors are not in the repository; fetch them from package.toml.
install_yazi_packages() {
  export PATH="$dotfiles_home/.local/bin:$PATH"
  command -v ya >/dev/null 2>&1 || return 0
  ya pkg install || say "warning: ya pkg install failed; rerun it later"
}

install_dependencies() {
  case "$(uname -s)" in
    Linux)
      require_command apt-get
      apt_updated=false
      if ! command -v dpkg-query >/dev/null 2>&1 \
        || ! dpkg-query -W zsh git ca-certificates stow curl unzip >/dev/null 2>&1; then
        run_apt update
        apt_updated=true
        run_apt install -y zsh git ca-certificates stow curl unzip
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
      install_nvim_release
      if ! command -v zoxide >/dev/null 2>&1; then
        if [ "$apt_updated" = false ]; then
          run_apt update
        fi
        run_apt install -y zoxide
        require_command zoxide
      fi
      install_yazi_release
      install_nerd_font
      ;;
    Darwin)
      if ! command -v stow >/dev/null 2>&1; then
        require_command brew
        brew install stow
        require_command stow
      fi
      if ! command -v bat >/dev/null 2>&1 \
        && [ ! -x "$dotfiles_home/.local/bin/bat" ]; then
        require_command brew
        brew install bat
        require_command bat
      fi
      if ! nvim_is_current "$(command -v nvim || true)"; then
        require_command brew
        brew install neovim
        require_command nvim
      fi
      if ! command -v zoxide >/dev/null 2>&1; then
        require_command brew
        brew install zoxide
        require_command zoxide
      fi
      if ! command -v yazi >/dev/null 2>&1; then
        require_command brew
        brew install yazi
        require_command yazi
      fi
      ;;
    *)
      fail "supported operating systems: Ubuntu, Debian, macOS"
      ;;
  esac

  require_command git
  require_command stow
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

# DOTFILES_EXTRA_DIR adds a second directory of Stow packages, for example
# machine-specific configs kept in another repository.
apply_config() {
  for stow_dir in "$dotfiles_dir" ${DOTFILES_EXTRA_DIR:+"$DOTFILES_EXTRA_DIR"}; do
    [ -d "$stow_dir" ] || fail "$stow_dir is not a directory"
    for package_dir in "$stow_dir"/*/; do
      [ -d "$package_dir" ] || continue
      package=$(basename "$package_dir")

      # Stow refuses to replace files it does not own, so move them aside first.
      while IFS= read -r source_path; do
        config_target="$dotfiles_home/${source_path#"$package_dir"}"
        if { [ -e "$config_target" ] || [ -L "$config_target" ]; } \
          && ! [ "$config_target" -ef "$source_path" ]; then
          backup_path="$config_target.backup.$(date +%Y%m%d%H%M%S)"
          if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
            backup_path="$backup_path.$$"
          fi
          mv "$config_target" "$backup_path"
          say "Backed up existing config: $backup_path"
        fi
      done < <(find "$package_dir" -type f)

      # No folding keeps app-written files (plugins, logs) out of the repository.
      stow --dir "$stow_dir" --target "$dotfiles_home" --no-folding \
        --restow "$package"
    done
  done
}

install_all() {
  install_dependencies
  ensure_plugins
  apply_config
  install_yazi_packages
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
