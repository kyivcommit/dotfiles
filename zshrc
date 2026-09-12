export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

ZSH_THEME="robbyrussell"

# Cross-platform tool paths. Missing directories are ignored.
for tool_path in \
  "$HOME/.local/bin" \
  "$HOME/.cargo/bin" \
  /opt/homebrew/opt/mysql-client/bin \
  /usr/local/opt/mysql-client/bin \
  /opt/homebrew/opt/rustup/bin \
  /usr/local/opt/rustup/bin
do
  [[ -d "$tool_path" ]] && path=("$tool_path" $path)
done
typeset -U path PATH

plugins=(
  git
  z
  vi-mode
  zsh-autosuggestions
  fzf-zsh-plugin
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

export EDITOR="vim"
export VISUAL="vim"

export VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
export VI_MODE_SET_CURSOR=true
export MODE_INDICATOR="%F{red}-N-%f"
export INSERT_MODE_INDICATOR="%F{green}-I-%f"
export KEYTIMEOUT=1

# Ukrainian layout mapping for vi command mode.
function () {
  local qwerty='qwertyuiop[]asdfghjkl;'\''zxcvbnm,./QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?'
  local cyrillic='йцукенгшщзхїфівапролджєячсмитьбю.ЙЦУКЕНГШЩЗХЇФІВАПРОЛДЖЄЯЧСМИТЬБЮ,'
  local i
  for i in {1..$#qwerty}; do
    bindkey -s -M vicmd "${cyrillic[$i]}" "${qwerty[$i]}"
  done
}

# Secrets, host-specific paths, and aliases stay outside Git.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
