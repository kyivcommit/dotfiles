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
[ -f "$root/zshrc" ] || fail "zshrc is missing"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
fake_log="$test_root/commands.log"
mkdir -p "$fake_bin"
: >"$fake_log"

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_UNAME:?}"
EOF

cat >"$fake_bin/id" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "-u" ] && printf '0\n'
EOF

cat >"$fake_bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get|%s\n' "$*" >>"${FAKE_LOG:?}"
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

run_install() {
  DOTFILES_HOME=$1 \
  FAKE_UNAME=$2 \
  FAKE_LOG=$fake_log \
  PATH="$fake_bin:/usr/bin:/bin" \
    "$script" "$3"
}

linux_home="$test_root/linux-home"
mkdir -p "$linux_home"
printf 'old config\n' >"$linux_home/.zshrc"

run_install "$linux_home" Linux install

[ -L "$linux_home/.zshrc" ] || fail "install did not create .zshrc symlink"
[ "$(readlink "$linux_home/.zshrc")" = "$root/zshrc" ] || fail "symlink points to wrong config"
backup=$(find "$linux_home" -maxdepth 1 -name '.zshrc.backup.*' -type f -print -quit)
[ -n "$backup" ] || fail "existing .zshrc was not backed up"
assert_file_contains "$backup" "old config"

for plugin in zsh-syntax-highlighting fzf-zsh-plugin; do
  [ -d "$linux_home/.oh-my-zsh/custom/plugins/$plugin/.git" ] || fail "$plugin was not installed"
done
[ ! -e "$linux_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ] \
  || fail "bundled zsh-autosuggestions was cloned as a custom plugin"

assert_file_contains "$fake_log" "apt-get|update"
assert_file_contains "$fake_log" "apt-get|install -y zsh git ca-certificates"

clone_count=$(grep -c '^clone|' "$fake_log")
run_install "$linux_home" Linux install
[ "$(grep -c '^clone|' "$fake_log")" -eq "$clone_count" ] || fail "second install cloned repositories again"

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

mac_home="$test_root/mac-home"
mkdir -p "$mac_home"
apt_count=$(grep -c '^apt-get|' "$fake_log")
run_install "$mac_home" Darwin install
[ "$(grep -c '^apt-get|' "$fake_log")" -eq "$apt_count" ] || fail "macOS install invoked apt-get"

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
    PATH="$fake_bin:/usr/bin:/bin" \
      script -q /dev/null "$script" install </dev/null >/dev/null
    ;;
  Linux)
    printf -v tty_command \
      'DOTFILES_HOME=%q FAKE_UNAME=Darwin FAKE_LOG=%q PATH=%q %q install' \
      "$tty_home" "$fake_log" "$fake_bin:/usr/bin:/bin" "$script"
    script -qec "$tty_command" /dev/null </dev/null >/dev/null
    ;;
  *)
    fail "test requires macOS or Linux"
    ;;
esac
assert_file_contains "$fake_log" "zsh|-l"

printf 'PASS: install, update, plugin update, idempotency, Linux/macOS branches\n'
