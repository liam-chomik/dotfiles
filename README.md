# dotfiles

Terminal configuration for WSL2 (Ubuntu) under Windows Terminal, themed
consistently with [Gruvbox Material](https://github.com/sainnhe/gruvbox-material)
Dark across every tool.

## Contents

| Path | Target | Purpose |
| --- | --- | --- |
| `zshrc` | `~/.zshrc` | Shell: history, completion, plugins, aliases, tool init |
| `vimrc` | `~/.vimrc` | Vim: statusline, persistent undo, WSL clipboard bridge |
| `gitconfig` | `~/.gitconfig` | Git: diff and log formatting, safety defaults |
| `gitignore_global` | `~/.gitignore_global` | Editor, OS, and credential patterns ignored in every repo |
| `inputrc` | `~/.inputrc` | Readline: bash, Python REPL, gdb, sqlite3, psql |
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

Three manual steps remain.

**1. Set the commit identity**, before `install.sh` on a machine that already
has a working `~/.gitconfig`. `gitconfig` sets `user.useConfigOnly`, so git
refuses to invent an identity from `$USER@$HOSTNAME` and the first commit fails
without this:

```sh
git config -f ~/.gitconfig_local user.name  "Your Name"
git config -f ~/.gitconfig_local user.email "you@example.com"
```

**2. Make zsh the login shell.** Needs a real terminal for authentication:

```sh
chsh -s "$(which zsh)"
```

**3. Register the bat theme**, which bat reads from its own cache:

```sh
bat cache --build
```

## Local overrides

Two files stay outside version control so machine-specific settings never reach
a commit. Both are optional and sourced last, so either can override anything
the tracked configs set.

| File | Read by |
| --- | --- |
| `~/.gitconfig_local` | `gitconfig`, through an `[include]` at the end |
| `~/.zshrc_local` | `zshrc`, sourced at the end |

## Dependencies

`zsh`, `vim` 9.1+, `tmux` 3.2+, `git`, and
[starship](https://starship.rs),
[eza](https://github.com/eza-community/eza),
[bat](https://github.com/sharkdp/bat),
[fzf](https://github.com/junegunn/fzf),
[zoxide](https://github.com/ajeetdsouza/zoxide),
[fastfetch](https://github.com/fastfetch-cli/fastfetch).

tmux 3.2 is the floor because `terminal-features` replaced the older
`terminal-overrides` mechanism there; vim 9.1 because the clipboard bridge uses
`v:clipproviders`.

Optional, each degrading rather than breaking:
[fd](https://github.com/sharkdp/fd) and
[ripgrep](https://github.com/BurntSushi/ripgrep) back fzf's file walk and vim's
`:grep`, falling back to fzf's own walk and system grep without them. Debian
packages fd as `fdfind`, which is the name `zshrc` looks for; `zshrc` aliases
`fd` back onto it when present.

`xclip` backs the vim clipboard bridge. Without it the bridge falls back to
`clip.exe`, which costs a Windows process launch per copy and so leaves plain
yank local rather than routing every yank through it.

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
