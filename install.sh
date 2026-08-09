#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory this script lives in, so it works regardless of
# where it's invoked from (e.g. `~/dotfiles/install.sh` vs `./install.sh`).
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source:dest pairs, relative to $DOTFILES and $HOME respectively.
LINKS=(
  "zshrc:.zshrc"
  "vimrc:.vimrc"
  "starship.toml:.config/starship.toml"
  "tmux:.config/tmux"
  "bat:.config/bat"
  "eza:.config/eza"
  "fastfetch:.config/fastfetch"
)

# Vim plugins are their own git repos, so they're cloned rather than committed
# here (a nested checkout inside this repo would be a submodule headache).
# Anything under ~/.vim/pack/*/start/ is loaded automatically by Vim 8+.
VIM_PACKS=(
  "https://github.com/sainnhe/gruvbox-material.git:themes/gruvbox-material"
)

for entry in "${LINKS[@]}"; do
  src="${entry%%:*}"
  dest="${entry##*:}"
  src_path="$DOTFILES/$src"
  dest_path="$HOME/$dest"

  mkdir -p "$(dirname "$dest_path")"

  # Already correctly linked -> nothing to do. Makes the script idempotent.
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
  url="${entry%:*}"          # trailing field is group/name, so cut at the LAST colon
  spec="${entry##*:}"        # e.g. "themes/gruvbox-material"
  group="${spec%%/*}"        # "themes"
  name="${spec##*/}"         # "gruvbox-material"
  path="$HOME/.vim/pack/$group/start/$name"

  if [ -d "$path/.git" ]; then
    echo "already installed: $path"
    continue
  fi

  mkdir -p "$(dirname "$path")"
  git clone --depth 1 "$url" "$path"
  echo "cloned $url -> $path"
done
