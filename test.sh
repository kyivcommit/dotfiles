#!/usr/bin/env bash
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
script="$root/install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file_contains() {
  grep -F -- "$2" "$1" >/dev/null || fail "$1 does not contain: $2"
}

[ -x "$script" ] || fail "install.sh is missing or not executable"
[ -f "$root/zsh/.zshrc" ] || fail "zsh/.zshrc is missing"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
fake_log="$test_root/commands.log"
mkdir -p "$fake_bin"
: >"$fake_log"

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-m" ]; then printf 'x86_64\n'; else printf '%s\n' "${FAKE_UNAME:?}"; fi
EOF

cat >"$fake_bin/id" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "-u" ] && printf '0\n'
EOF

cat >"$fake_bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

cat >"$fake_bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get|%s\n' "$*" >>"${FAKE_LOG:?}"
if [ "${1:-}" = install ] && [ "${*: -1}" = bat ]; then
  printf '#!/usr/bin/env bash\n' >"$(dirname "$0")/batcat"
  chmod +x "$(dirname "$0")/batcat"
fi
if [ "${1:-}" = install ] && [ "${*: -1}" = zoxide ]; then
  printf '#!/usr/bin/env bash\n' >"$(dirname "$0")/zoxide"
  chmod +x "$(dirname "$0")/zoxide"
fi
EOF

cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew|%s\n' "$*" >>"${FAKE_LOG:?}"
if [ "${1:-}" = install ] && [ "${2:-}" = bat ]; then
  printf '#!/usr/bin/env bash\n' >"$(dirname "$0")/bat"
  chmod +x "$(dirname "$0")/bat"
fi
if [ "${1:-}" = install ] && [ "${2:-}" = neovim ]; then
  printf '#!/usr/bin/env bash\necho "NVIM v0.12.5"\n' >"$(dirname "$0")/nvim"
  chmod +x "$(dirname "$0")/nvim"
fi
if [ "${1:-}" = install ] && [ "${2:-}" = yazi ]; then
  printf '#!/usr/bin/env bash\n' >"$(dirname "$0")/yazi"
  printf '#!/usr/bin/env bash\nprintf "ya|%%s\\n" "$*" >>"${FAKE_LOG:?}"\n' >"$(dirname "$0")/ya"
  chmod +x "$(dirname "$0")/yazi" "$(dirname "$0")/ya"
fi
if [ "${1:-}" = install ] && [ "${2:-}" = zoxide ]; then
  printf '#!/usr/bin/env bash\n' >"$(dirname "$0")/zoxide"
  chmod +x "$(dirname "$0")/zoxide"
fi
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl|%s\n' "$*" >>"${FAKE_LOG:?}"
while [ "$#" -gt 1 ]; do
  [ "$1" = -o ] && : >"$2"
  shift
done
EOF

cat >"$fake_bin/unzip" <<'EOF'
#!/usr/bin/env bash
printf 'unzip|%s\n' "$*" >>"${FAKE_LOG:?}"
destination=
for argument in "$@"; do
  [ "${previous:-}" = -d ] && destination=$argument
  previous=$argument
done
case "$*" in
  *FiraCode.zip*)
    mkdir -p "$destination"
    : >"$destination/FiraCodeNerdFontMono-Regular.ttf"
    exit 0
    ;;
esac
directory="$destination/yazi-x86_64-unknown-linux-gnu"
mkdir -p "$directory"
printf '#!/usr/bin/env bash\n' >"$directory/yazi"
cat >"$directory/ya" <<'INNER'
#!/usr/bin/env bash
printf 'ya|%s\n' "$*" >>"${FAKE_LOG:?}"
INNER
chmod +x "$directory/yazi" "$directory/ya"
EOF

cat >"$fake_bin/fc-cache" <<'EOF'
#!/usr/bin/env bash
printf 'fc-cache|%s\n' "$*" >>"${FAKE_LOG:?}"
EOF

cat >"$fake_bin/tar" <<'EOF'
#!/usr/bin/env bash
printf 'tar|%s\n' "$*" >>"${FAKE_LOG:?}"
destination=
for argument in "$@"; do
  [ "${previous:-}" = -C ] && destination=$argument
  previous=$argument
done
mkdir -p "$destination/nvim-linux-x86_64/bin"
printf '#!/usr/bin/env bash\necho "NVIM v%s"\n' "${FAKE_NVIM_VERSION:-0.12.5}" \
  >"$destination/nvim-linux-x86_64/bin/nvim"
chmod +x "$destination/nvim-linux-x86_64/bin/nvim"
EOF

cat >"$fake_bin/zsh" <<'EOF'
#!/usr/bin/env bash
printf 'zsh|%s\n' "$*" >>"${FAKE_LOG:?}"
exit 0
EOF

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -eu

if [ "${1:-}" = "-C" ]; then
  repo=$2
  shift 2
  printf 'pull|%s|%s\n' "$repo" "$*" >>"${FAKE_LOG:?}"
  exit 0
fi

if [ "${1:-}" = "clone" ]; then
  destination=
  for argument in "$@"; do destination=$argument; done
  printf 'clone|%s\n' "$destination" >>"${FAKE_LOG:?}"
  mkdir -p "$destination/.git"
  case "$destination" in
    */.oh-my-zsh)
      mkdir -p "$destination/plugins/git" \
        "$destination/plugins/z" \
        "$destination/plugins/vi-mode" \
        "$destination/plugins/zsh-autosuggestions" \
        "$destination/custom/plugins"
      ;;
  esac
  exit 0
fi

printf 'unexpected git invocation: %s\n' "$*" >&2
exit 1
EOF

chmod +x "$fake_bin"/*
for utility in bash awk cat chmod date dirname ln mkdir mv readlink script stow find basename mktemp install rm sed sort head; do
  ln -s "$(command -v "$utility")" "$fake_bin/$utility"
done

run_install() {
  DOTFILES_HOME=$1 \
  FAKE_UNAME=$2 \
  FAKE_LOG=$fake_log \
  PATH="$fake_bin" \
    "$script" "$3"
}

export DOTFILES_SHARE_DIR="$test_root/share"
mkdir -p "$DOTFILES_SHARE_DIR/xsessions"

linux_home="$test_root/linux-home"
mkdir -p "$linux_home"
printf 'old config\n' >"$linux_home/.zshrc"

run_install "$linux_home" Linux install

[ -L "$linux_home/.zshrc" ] || fail "install did not create .zshrc symlink"
[ "$linux_home/.zshrc" -ef "$root/zsh/.zshrc" ] || fail "symlink points to wrong config"
[ "$linux_home/.config/nvim/init.lua" -ef "$root/nvim/.config/nvim/init.lua" ] \
  || fail "install did not link nested package files"
[ ! -L "$linux_home/.config/nvim" ] || fail "stow folded a package directory"
backup=$(find "$linux_home" -maxdepth 1 -name '.zshrc.backup.*' -type f -print -quit)
[ -n "$backup" ] || fail "existing .zshrc was not backed up"
assert_file_contains "$backup" "old config"

for plugin in zsh-syntax-highlighting fzf-zsh-plugin; do
  [ -d "$linux_home/.oh-my-zsh/custom/plugins/$plugin/.git" ] || fail "$plugin was not installed"
done
[ ! -e "$linux_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ] \
  || fail "bundled zsh-autosuggestions was cloned as a custom plugin"

assert_file_contains "$fake_log" "apt-get|update"
assert_file_contains "$fake_log" "apt-get|install -y zsh git ca-certificates stow curl unzip"
assert_file_contains "$fake_log" "apt-get|install -y bat"
assert_file_contains "$fake_log" "tar|-xzf"
[ "$("$linux_home/.local/bin/nvim" --version)" = "NVIM v0.12.5" ] \
  || fail "Linux install did not install a current Neovim"
assert_file_contains "$fake_log" "apt-get|install -y zoxide"
assert_file_contains "$fake_log" "unzip|"
[ -x "$linux_home/.local/bin/yazi" ] || fail "Linux install did not install yazi"
[ -x "$linux_home/.local/bin/ya" ] || fail "Linux install did not install ya"
assert_file_contains "$fake_log" "ya|pkg install"
[ -f "$linux_home/.local/share/fonts/FiraCodeNerdFont/FiraCodeNerdFontMono-Regular.ttf" ] \
  || fail "desktop Linux install did not install the Nerd Font"
assert_file_contains "$fake_log" "fc-cache|-f"
[ -L "$linux_home/.local/bin/bat" ] || fail "Linux install did not link bat"
[ "$(readlink "$linux_home/.local/bin/bat")" = "$fake_bin/batcat" ] \
  || fail "Linux bat link points to wrong executable"

clone_count=$(grep -c '^clone|' "$fake_log")
run_install "$linux_home" Linux install
[ "$(grep -c '^clone|' "$fake_log")" -eq "$clone_count" ] || fail "second install cloned repositories again"
[ "$(grep -c '^curl|' "$fake_log")" -eq 3 ] \
  || fail "second install downloaded yazi, the font, or Neovim again"
[ "$(grep -c '^apt-get|install -y bat$' "$fake_log")" -eq 1 ] \
  || fail "second install reinstalled bat"

run_install "$linux_home" Linux update
assert_file_contains "$fake_log" "pull|$root|pull --ff-only"

run_install "$linux_home" Linux update-plugins
assert_file_contains "$fake_log" "pull|$linux_home/.oh-my-zsh|pull --ff-only"
for plugin in zsh-syntax-highlighting fzf-zsh-plugin; do
  assert_file_contains "$fake_log" "pull|$linux_home/.oh-my-zsh/custom/plugins/$plugin|pull --ff-only"
done
if grep -F "pull|$linux_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions|" "$fake_log" >/dev/null; then
  fail "update tried to pull bundled zsh-autosuggestions as a custom plugin"
fi

old_nvim_home="$test_root/old-nvim-home"
mkdir -p "$old_nvim_home"
printf '#!/usr/bin/env bash\necho "NVIM v0.9.5"\n' >"$fake_bin/nvim"
chmod +x "$fake_bin/nvim"
run_install "$old_nvim_home" Linux install
[ "$("$old_nvim_home/.local/bin/nvim" --version)" = "NVIM v0.12.5" ] \
  || fail "outdated Neovim was not replaced"
rm "$fake_bin/nvim"

extra_dir="$test_root/extra"
mkdir -p "$extra_dir/extra-pkg/.config/extra"
printf 'extra\n' >"$extra_dir/extra-pkg/.config/extra/config"
mkdir -p "$extra_dir/fold-pkg/.config/fold"
: >"$extra_dir/fold-pkg/.stow-fold"
printf 'fold\n' >"$extra_dir/fold-pkg/.config/fold/config"
extra_home="$test_root/extra-home"
mkdir -p "$extra_home"
DOTFILES_EXTRA_DIR="$extra_dir" run_install "$extra_home" Linux install
[ "$extra_home/.config/extra/config" -ef "$extra_dir/extra-pkg/.config/extra/config" ] \
  || fail "extra directory package was not linked"
[ "$extra_home/.zshrc" -ef "$root/zsh/.zshrc" ] || fail "extra install skipped main packages"
[ -L "$extra_home/.config/fold" ] || fail ".stow-fold package was not linked as a directory"
[ ! -e "$extra_home/.stow-fold" ] || fail ".stow-fold marker was linked"
[ ! -L "$extra_home/.config/extra" ] || fail "package without .stow-fold was folded"

headless_home="$test_root/headless-home"
mkdir -p "$headless_home"
DOTFILES_SHARE_DIR="$test_root/no-desktop" run_install "$headless_home" Linux install
[ ! -e "$headless_home/.local/share/fonts" ] || fail "headless install installed fonts"

mac_home="$test_root/mac-home"
mkdir -p "$mac_home"
rm "$fake_bin/nvim" "$fake_bin/zoxide" "$fake_bin/yazi" "$fake_bin/ya" 2>/dev/null || true
apt_count=$(grep -c '^apt-get|' "$fake_log")
run_install "$mac_home" Darwin install
[ "$(grep -c '^apt-get|' "$fake_log")" -eq "$apt_count" ] || fail "macOS install invoked apt-get"
assert_file_contains "$fake_log" "brew|install bat"
assert_file_contains "$fake_log" "brew|install neovim"
assert_file_contains "$fake_log" "brew|install zoxide"
assert_file_contains "$fake_log" "brew|install yazi"
[ ! -e "$mac_home/.local/bin/bat" ] || fail "macOS install created a batcat link"
run_install "$mac_home" Darwin install
[ "$(grep -c '^brew|install bat$' "$fake_log")" -eq 1 ] \
  || fail "second macOS install reinstalled bat"
[ "$(grep -c '^brew|install neovim$' "$fake_log")" -eq 1 ] \
  || fail "second macOS install reinstalled neovim"
[ "$(grep -c '^brew|install zoxide$' "$fake_log")" -eq 1 ] \
  || fail "second macOS install reinstalled zoxide"
[ "$(grep -c '^brew|install yazi$' "$fake_log")" -eq 1 ] \
  || fail "second macOS install reinstalled yazi"

if run_install "$test_root/unknown-home" FreeBSD install 2>/dev/null; then
  fail "unsupported OS succeeded"
fi

tty_home="$test_root/tty-home"
mkdir -p "$tty_home"
case "$(/usr/bin/uname -s)" in
  Darwin)
    DOTFILES_HOME=$tty_home \
    FAKE_UNAME=Darwin \
    FAKE_LOG=$fake_log \
    PATH="$fake_bin" \
      script -q /dev/null "$script" install </dev/null >/dev/null
    ;;
  Linux)
    printf -v tty_command \
      'DOTFILES_HOME=%q FAKE_UNAME=Darwin FAKE_LOG=%q PATH=%q %q install' \
      "$tty_home" "$fake_log" "$fake_bin" "$script"
    script -qec "$tty_command" /dev/null </dev/null >/dev/null
    ;;
  *)
    fail "test requires macOS or Linux"
    ;;
esac
assert_file_contains "$fake_log" "zsh|-l"

printf 'PASS: install, update, plugin update, idempotency, Linux/macOS branches\n'
