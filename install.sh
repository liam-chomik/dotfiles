#!/usr/bin/env bash
#
# Symlink the configs in this repo into $HOME and fetch the vim and zsh plugins.
# Idempotent: re-running reports what is already in place and changes nothing.
# Anything already at a destination is backed up rather than overwritten.

set -euo pipefail

# Resolve the directory this script lives in, so it runs correctly from any cwd.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source:dest pairs, relative to $DOTFILES and $HOME respectively.
LINKS=(
  "zshrc:.zshrc"
  "vimrc:.vimrc"
  "gitconfig:.gitconfig"
  "gitignore_global:.gitignore_global"
  "inputrc:.inputrc"
  "starship.toml:.config/starship.toml"
  "tmux:.config/tmux"
  "bat:.config/bat"
  "eza:.config/eza"
  "fastfetch:.config/fastfetch"
)

# url:group/name pairs. Vim plugins are separate git repos, so they are cloned
# at install time rather than vendored here. Vim 8+ loads anything under
# ~/.vim/pack/*/start/ automatically. The group is cosmetic to vim and only
# separates the colorscheme from the plugins vimrc configures.
#
# Every entry here is referenced by vimrc; dropping one leaves mappings and
# plugin settings pointing at nothing.
VIM_PACKS=(
  "https://github.com/sainnhe/gruvbox-material.git:themes/gruvbox-material"
  "https://github.com/ctrlpvim/ctrlp.vim.git:plugins/ctrlp.vim"
  "https://github.com/mileszs/ack.vim.git:plugins/ack.vim"
)

# Cloned into ~/.zsh/<name>, where zshrc sources each one by path. Unlike vim
# packages these are not autoloaded, so the order zshrc sources them in is what
# matters, not the order here.
ZSH_PLUGINS=(
  "https://github.com/zsh-users/zsh-autosuggestions.git"
  "https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

# Clone $1 into $2 unless a git repo is already there. A non-repo sitting at the
# destination is left untouched and reported: unlike the symlink targets below
# it could be an unrelated directory, so moving it aside is not obviously safe.
clone_repo() {
  local url="$1" path="$2"

  if [ -d "$path/.git" ]; then
    echo "already installed: $path"
    return
  fi

  if [ -e "$path" ]; then
    echo "not a git repo, skipping: $path (remove it to install $url)" >&2
    return
  fi

  mkdir -p "$(dirname "$path")"
  git clone --depth 1 "$url" "$path"
  echo "cloned $url -> $path"
}

for entry in "${LINKS[@]}"; do
  src="${entry%%:*}"
  dest="${entry##*:}"
  src_path="$DOTFILES/$src"
  dest_path="$HOME/$dest"

  mkdir -p "$(dirname "$dest_path")"

  # Already correctly linked, nothing to do.
  if [ -L "$dest_path" ] && [ "$(readlink "$dest_path")" = "$src_path" ]; then
    echo "already linked: $dest_path"
    continue
  fi

  # Something else is there (a real file/dir, or a symlink pointing
  # elsewhere, including a broken one) -> preserve it instead of clobbering.
  if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
    backup="$dest_path.bak.$(date +%s)"
    echo "backing up existing $dest_path -> $backup"
    mv "$dest_path" "$backup"
  fi

  ln -s "$src_path" "$dest_path"
  echo "linked $dest_path -> $src_path"
done

for entry in "${VIM_PACKS[@]}"; do
  url="${entry%:*}"          # cut at the final colon; the url contains one too
  spec="${entry##*:}"
  group="${spec%%/*}"
  name="${spec##*/}"

  clone_repo "$url" "$HOME/.vim/pack/$group/start/$name"
done

for url in "${ZSH_PLUGINS[@]}"; do
  name="$(basename "$url" .git)"

  clone_repo "$url" "$HOME/.zsh/$name"
done
