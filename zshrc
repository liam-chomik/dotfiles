# ~/.zshrc
# Interactive shell configuration. Theme: Gruvbox Material Dark.

# --- PATH ---
# zsh ties the path array to PATH; -U keeps it deduplicated. Without it, a
# nested shell re-runs the line below and appends a second copy of the entry,
# which compounds with every further nesting.
typeset -U path PATH
export PATH="$HOME/.local/bin:$PATH"

# WSL appends the whole Windows PATH, which lands roughly twenty directories on
# the 9p mount. Every command lookup and every completion walks them, and 9p
# makes each stat a round trip: dropping them takes interactive startup from
# ~0.16s to ~0.11s.
#
# system32 is added back because clip.exe lives there, and both the vim
# clipboard bridge and the tmux copy binding resolve it through $PATH. It is
# re-added by literal path rather than matched out of the list, so the filter
# needs no case-insensitive glob for a directory Windows spells inconsistently.
path=( ${path:#/mnt/c/*} )
[[ -d /mnt/c/WINDOWS/system32 ]] && path+=( /mnt/c/WINDOWS/system32 )

# --- default editor (git commit messages, crontab, less -v, etc.) ---
export EDITOR="vim"
export VISUAL="vim"

# --- history ---
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY   # record a timestamp and duration per entry

# Commands matching this pattern are not written to the history file. Listing
# and navigation noise otherwise crowds out the entries worth searching back to.
HISTORY_IGNORE='(ls|ll|la|lt|cd|cd ..|-|pwd|exit|clear|fastfetch|fg|bg)'

# --- useful zsh options ---
setopt AUTO_CD                # type a dir name to cd into it
setopt CORRECT                # suggest corrections for mistyped commands
setopt INTERACTIVE_COMMENTS   # allow # comments in a pasted command line

# --- completion ---
# Rebuild the dump at most once a day and load the cache otherwise: a full
# compinit costs ~108ms against ~13ms for compinit -C.
#
# Two details this depends on. The glob needs array context, because filename
# generation does not run inside [[ ]], where the widely posted one-line form
# tests a literal string and always takes the cached branch. And the explicit
# touch is required because compinit only rewrites the dump when the
# completion functions changed, so without it the mtime never advances and
# every shell takes the slow branch forever.
autoload -Uz compinit
_zcompdump_fresh=( ~/.zcompdump(Nmh-24) )
if (( $#_zcompdump_fresh )); then
  compinit -C
else
  compinit
  touch ~/.zcompdump
fi
unset _zcompdump_fresh

# Navigable completion menu once a listing exceeds four entries, rather than a
# flat list that has to be retyped against.
zmodload zsh/complist
zstyle ':completion:*' menu select=4
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# --- line editing ---
# Ctrl-x Ctrl-e opens the current command line in $EDITOR, which is the way to
# fix a long pipeline without retyping it.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# --- plugins ---
[[ -r ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# Must be sourced last among plugins.
[[ -r ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- fzf (fuzzy finder: Ctrl+R history, Ctrl+T files, Alt+C cd) ---
(( $+commands[fzf] )) && eval "$(fzf --zsh)"

# The default walk shells out to find, which descends into .git and any
# dependency directory. Debian ships fd as fdfind, the name colliding with an
# unrelated package, so the upstream binary name is not available.
#
# Both variables stay unset when neither tool is present. fzf distinguishes
# unset from empty: an empty FZF_CTRL_T_COMMAND suppresses the Ctrl-T binding
# entirely, where leaving it unset falls back to fzf's own walk.
if (( $+commands[fdfind] )); then
  export FZF_DEFAULT_COMMAND='fdfind --type file --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
elif (( $+commands[rg] )); then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS=" \
--height 40% --layout=reverse --border \
--color=bg+:#45403D,bg:#282828,spinner:#d8a657,hl:#ea6962 \
--color=fg:#d4be98,header:#ea6962,info:#d3869b,pointer:#d8a657 \
--color=marker:#d8a657,fg+:#d4be98,prompt:#d3869b,hl+:#ea6962"

# --- tool-dependent aliases ---
# Shadowing a core command with a replacement that is not installed leaves the
# shell without a working ls or cat, on exactly the fresh machine where they are
# needed to install it. install.sh links configs but does not install these.
alias_if_exists() {
  (( $+commands[$1] )) && alias "$2"="$3"
}

# --- eza (replaces ls) ---
export EZA_CONFIG_DIR="$HOME/.config/eza"
alias_if_exists eza ls 'eza --icons --group-directories-first'
alias_if_exists eza ll 'eza --icons --group-directories-first -l --group --links'
alias_if_exists eza la 'eza --icons --group-directories-first -lah --group --links'
alias_if_exists eza lt 'eza --icons --tree --level=2'

# --- bat (replaces cat) ---
export BAT_THEME="Gruvbox-Material-Dark"
alias_if_exists bat cat 'bat --paging=never'

# man pages through bat, so they pick up the same theme. col -bx strips the
# backspace overprinting groff uses for bold, and MANROFFOPT=-c stops groff
# emitting the escape sequences bat would then render literally. Guarded because
# an unset MANPAGER falls back to less, while a broken one breaks man outright.
if (( $+commands[bat] )); then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# --- functions ---

# Update these dotfiles and reapply them.
dfu() {
  ( cd ~/dotfiles && git pull --ff-only && ./install.sh )
}

# Pick processes with fzf and signal them. Tab marks several. Defaults to
# SIGKILL; pass a signal as the first argument for anything gentler, which is
# usually the right first attempt since SIGKILL skips cleanup handlers.
fkill() {
  local pids
  pids=$(ps -eo pid,user,%cpu,%mem,command --sort=-%cpu | sed 1d | fzf -m | awk '{print $1}')
  [[ -n "$pids" ]] && echo "$pids" | xargs kill "-${1:-KILL}"
}

# --- fastfetch banner on new interactive shell ---
if [[ $- == *i* ]] && (( $+commands[fastfetch] )); then
  fastfetch
fi

# --- prompt ---
# Unguarded, a missing starship leaves the shell with no prompt at all.
(( $+commands[starship] )) && eval "$(starship init zsh)"

# --- zoxide (replaces cd) ---
# Interactive only: the precmd hook never fires otherwise, which zoxide's own
# doctor check reports as a misconfiguration.
if [[ $- == *i* ]] && (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

# --- Locale ---
export TZ=America/Argentina/Buenos_Aires

# --- machine-specific settings ---
# Untracked, and sourced last so it can override anything above. The shell
# counterpart to the ~/.gitconfig_local include in gitconfig.
#
# An if block rather than `[[ ... ]] && source`: the last statement's status
# becomes $? for the first prompt, and a false test would open every shell
# showing an error in the prompt.
if [[ -r ~/.zshrc_local ]]; then
  source ~/.zshrc_local
fi
