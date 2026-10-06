export FZF_PREVIEW_WINDOW='right,50%'
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --no-height"

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

export EDITOR=nvim
export VISUAL=nvim

ZSH_THEME="robbyrussell"

# Cross-platform tool paths. Missing directories are ignored.
for tool_path in \
  "$HOME/.local/bin" \
  "$HOME/.cargo/bin" \
  /opt/homebrew/opt/mysql-client/bin \
  /usr/local/opt/mysql-client/bin \
  /opt/homebrew/opt/rustup/bin \
  /usr/local/opt/rustup/bin \
  /opt/homebrew/bin
do
  [[ -d "$tool_path" ]] && path=("$tool_path" $path)
done
typeset -U path PATH

plugins=(
  git
  # vi-mode
  zsh-autosuggestions
  fzf-zsh-plugin
  zsh-syntax-highlighting
)

# export VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
# export VI_MODE_SET_CURSOR=true
# export MODE_INDICATOR="%F%f"
# # export INSERT_MODE_INDICATOR="%F{green}-I-%f"
# export KEYTIMEOUT=5

source "$ZSH/oh-my-zsh.sh"

# Secrets, host-specific paths, and host-specific aliases stay outside Git.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

alias v="nvim"
