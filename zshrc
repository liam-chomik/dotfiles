# ~/.zshrc
# Interactive shell configuration. Theme: Gruvbox Material Dark.

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"

# --- default editor (git commit messages, crontab, less -v, etc.) ---
export EDITOR="vim"
export VISUAL="vim"

# --- history ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# --- useful zsh options ---
setopt AUTO_CD          # type a dir name to cd into it
setopt CORRECT          # suggest corrections for mistyped commands

# --- completion ---
autoload -Uz compinit && compinit

# --- plugins ---
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh   # must be sourced last among plugins

# --- fzf (fuzzy finder: Ctrl+R history, Ctrl+T files, Alt+C cd) ---
eval "$(fzf --zsh)"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#45403D,bg:#282828,spinner:#d8a657,hl:#ea6962 \
--color=fg:#d4be98,header:#ea6962,info:#d3869b,pointer:#d8a657 \
--color=marker:#d8a657,fg+:#d4be98,prompt:#d3869b,hl+:#ea6962"

# --- eza (replaces ls) ---
export EZA_CONFIG_DIR="$HOME/.config/eza"
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l --group --links'
alias la='eza --icons --group-directories-first -lah --group --links'
alias lt='eza --icons --tree --level=2'

# --- bat (replaces cat) ---
export BAT_THEME="Gruvbox-Material-Dark"
alias cat='bat --paging=never'

# --- fastfetch banner on new interactive shell ---
if [[ $- == *i* ]]; then
  fastfetch
fi

# --- prompt ---
eval "$(starship init zsh)"

# --- zoxide (replaces cd) ---
# Interactive only: the precmd hook never fires otherwise, which zoxide's own
# doctor check reports as a misconfiguration.
if [[ $- == *i* ]]; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# --- Locale ---
export TZ=America/Argentina/Buenos_Aires
