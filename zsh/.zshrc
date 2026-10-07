export FZF_PREVIEW_WINDOW='right,50%'
if command -v bat >/dev/null; then
  FZF_PREVIEWER="bat -n --color=always {}"
else
  FZF_PREVIEWER="cat {}"
fi
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target,dist,.venv,__pycache__
  --preview '$FZF_PREVIEWER'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --no-height"

umask 022

# History: shared across sessions, no dupes
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS \
    EXTENDED_HISTORY HIST_IGNORE_SPACE HIST_VERIFY \
    HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

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

# Falls back to a warning instead of a broken shell if oh-my-zsh is missing.
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  echo "zshrc: oh-my-zsh not found in $ZSH"
fi

# Secrets, host-specific paths, and host-specific aliases stay outside Git.
if [[ -r "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local" || echo "zshrc: failed to source ~/.zshrc.local"
fi

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

alias v="nvim"
