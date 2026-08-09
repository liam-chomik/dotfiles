# dotfiles

Terminal configuration for WSL2 (Ubuntu) under Windows Terminal, themed
consistently with [Gruvbox Material](https://github.com/sainnhe/gruvbox-material)
Dark across every tool.

## Contents

| Path | Target | Purpose |
| --- | --- | --- |
| `zshrc` | `~/.zshrc` | Shell: history, completion, plugins, aliases, tool init |
| `vimrc` | `~/.vimrc` | Vim: statusline, persistent undo, WSL clipboard bridge |
| `starship.toml` | `~/.config/starship.toml` | Prompt |
| `tmux/tmux.conf` | `~/.config/tmux/` | tmux: mouse, vi copy mode, status bar |
| `bat/themes/` | `~/.config/bat/` | `bat` syntax theme |
| `eza/theme.yml` | `~/.config/eza/` | `eza` colours |
| `fastfetch/config.jsonc` | `~/.config/fastfetch/` | Startup banner |

## Install

```sh
git clone git@github.com:liam-chomik/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh` symlinks each config into place and clones the vim and zsh plugins.
It is idempotent, and anything already sitting at a destination is moved to
`<name>.bak.<timestamp>` rather than overwritten.

Two manual steps remain:

```sh
chsh -s "$(which zsh)"     # requires a real terminal for authentication
bat cache --build          # register the bat theme
```

## Dependencies

`zsh`, `vim` 9.1+, `tmux` 3.x, `git`, and
[starship](https://starship.rs),
[eza](https://github.com/eza-community/eza),
[bat](https://github.com/sharkdp/bat),
[fzf](https://github.com/junegunn/fzf),
[zoxide](https://github.com/ajeetdsouza/zoxide),
[fastfetch](https://github.com/fastfetch-cli/fastfetch).

Vim and zsh plugins are cloned by `install.sh` and are not listed here; the
tables at the top of that script are the authoritative list.

## Notes

**A Nerd Font is required** for icons in `eza`, `starship`, and the vim
statusline to render. These configs are used with
[CaskaydiaCove NF](https://github.com/ryanoasis/nerd-fonts), set on the terminal
side rather than here.

**The vim clipboard bridge is WSL-specific.** Debian's `vim` ships without
`+clipboard`, so the `"+` and `"*` registers are wired to `clip.exe` and
`Get-Clipboard` through `+clipboard_provider` (Vim 9.1+). On a native Linux
install, delete that block and use a `+clipboard` build instead.

**Terminal colours are not in this repo.** The Windows Terminal scheme lives in
its own `settings.json`; these files assume a matching Gruvbox Material Dark
scheme is already active.
