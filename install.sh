#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory this script lives in, so it works regardless of
# where it's invoked from (e.g. `~/dotfiles/install.sh` vs `./install.sh`).
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source:dest pairs, relative to $DOTFILES and $HOME respectively.
LINKS=(
  "zshrc:.zshrc"
  "starship.toml:.config/starship.toml"
  "tmux:.config/tmux"
  "bat:.config/bat"
  "eza:.config/eza"
  "fastfetch:.config/fastfetch"
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
