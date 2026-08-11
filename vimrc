" ~/.vimrc
" Vim configuration for WSL2. Theme: Gruvbox Material Dark.

set nocompatible
filetype plugin indent on
syntax enable

" --- Appearance ---
set termguicolors
set background=dark

let g:gruvbox_material_background = 'medium'        " bg0 = #282828
let g:gruvbox_material_foreground = 'material'
let g:gruvbox_material_better_performance = 1
let g:gruvbox_material_enable_italic = 1
let g:gruvbox_material_diagnostic_text_highlight = 1
colorscheme gruvbox-material

set number relativenumber         " absolute on the cursor line, relative elsewhere
set signcolumn=yes                " always reserve the gutter so text does not shift
set showcmd
set noshowmode                    " the statusline reports the mode
set laststatus=2
set scrolloff=8
set sidescrolloff=8
set nowrap
set linebreak                     " break at word boundaries when wrap is enabled
set list
set listchars=tab:→\ ,trail:·,nbsp:␣,extends:>,precedes:<
set fillchars=vert:│,fold:·
set shortmess+=I                  " skip the intro screen

" Cursorline in the focused window only, so a split layout has one highlighted
" row rather than one per window.
augroup cursorline_active_window
  autocmd!
  autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
  autocmd WinLeave * setlocal nocursorline
augroup END

" Cursor shape per mode: bar in insert, underline in replace, block in normal.
let &t_SI = "\<Esc>[6 q"
let &t_SR = "\<Esc>[4 q"
let &t_EI = "\<Esc>[2 q"

" --- Behavior ---
set encoding=utf-8
set fileencoding=utf-8

" Modelines apply options written inside a file to the session that opens it,
" untrusted files included, and the sandbox meant to contain them has been
" escaped repeatedly, up to remote code execution. Disabled rather than
" whitelisted, so there is no boundary left to escape.
set nomodeline
set mouse=a                       " Shift bypasses this for native terminal selection
set belloff=all                   " covers the non-error bells 'noerrorbells' leaves ringing
set hidden                        " allow switching away from unsaved buffers
set confirm                       " prompt instead of failing on unsaved changes
set autoread
set backspace=indent,eol,start
set ttimeoutlen=10                " no delay when leaving insert mode
set updatetime=300
set history=1000
set splitbelow splitright
set nostartofline
set nojoinspaces                  " one space after a period when joining, not two
set lazyredraw                    " skip redrawing while a macro or mapping runs
set synmaxcol=500                 " stop highlighting past this column, so minified
                                  " and generated files stay responsive
set formatoptions+=j              " drop the comment leader when joining commented lines
set formatoptions+=n              " recognize numbered lists when formatting

" Diffs, matching diff.algorithm in gitconfig so vimdiff and git agree.
set diffopt+=algorithm:histogram
set diffopt+=indent-heuristic
set diffopt+=iwhite               " ignore whitespace-only changes

" Command-line completion
set wildmenu
set wildmode=longest:full,full
set wildignorecase
set wildignore+=*.o,*.obj,*.pyc,*.class,*/node_modules/*,*/.git/*

set path+=**                      " :find searches recursively from cwd

" --- Search ---
set incsearch
set hlsearch
set ignorecase
set smartcase                     " case-sensitive when the pattern contains a capital
set gdefault                      " :s replaces every match on a line by default

" --- Indentation ---
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set shiftround                    " round indent to a multiple of shiftwidth
set autoindent
set smartindent

augroup indent_overrides
  autocmd!
  autocmd FileType html,css,scss,javascript,typescript,json,yaml,lua,vim
        \ setlocal tabstop=2 softtabstop=2 shiftwidth=2
  autocmd FileType make,go setlocal noexpandtab
  autocmd FileType markdown,text,gitcommit setlocal wrap spell spelllang=en_us
  autocmd FileType gitcommit setlocal textwidth=72
augroup END

" --- Persistent state ---
" Kept out of the working directory. Mode 0700 because undo files hold the
" complete edit history of every file opened, including sensitive ones.
for s:dir in ['undo', 'swap', 'backup']
  let s:path = expand('~/.vim/' . s:dir)
  if !isdirectory(s:path)
    call mkdir(s:path, 'p', 0700)
  endif
endfor
unlet! s:dir s:path

set undofile
set undodir=~/.vim/undo//
set undolevels=1000
set directory=~/.vim/swap//
set nobackup
set writebackup                   " temporary backup during write, removed after
set backupdir=~/.vim/backup//
set viminfofile=~/.vim/viminfo

" Vim copies the edited file's permissions onto its undo file, and files on the
" Windows mount report 0777, which would leave edit history world-readable.
" Swap and backup files inherit the same way but are transient, so the 0700
" directory stays their only control.
function! s:HardenUndoFile() abort
  if !&undofile || empty(expand('%'))
    return
  endif
  let l:undo = undofile(expand('%:p'))
  if filereadable(l:undo)
    call setfperm(l:undo, 'rw-------')
  endif
endfunction

augroup harden_undo_perms
  autocmd!
  autocmd BufWritePost * call s:HardenUndoFile()
augroup END

" Restore the last cursor position
augroup restore_cursor
  autocmd!
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
        \ | execute "normal! g`\"" | endif
augroup END

" Conflict and reject leftovers are tool output, not sources to edit.
augroup readonly_artifacts
  autocmd!
  autocmd BufRead *.orig,*.rej setlocal readonly nomodifiable
augroup END

" Briefly highlight yanked text. The highlight is cleared from a timer rather
" than by sleeping, because 'clipboard' sends every yank and delete through the
" clipboard provider and a blocking sleep would add its full duration on top.
function! s:ClearYankHighlight(timer) abort
  silent! call matchdelete(9999)
endfunction

function! s:HighlightYank() abort
  silent! call matchdelete(9999)
  let l:pat = '\%' . line("'[") . 'l\%>' . (col("'[") - 1) . 'c\%<' . (col("']") + 1) . 'c'
  silent! call matchadd('IncSearch', l:pat, 10, 9999)
  call timer_start(150, function('s:ClearYankHighlight'))
endfunction

augroup highlight_yank
  autocmd!
  autocmd TextYankPost * call s:HighlightYank()
augroup END

" --- Clipboard bridge (WSL to Windows) ---
" Debian's vim is built without +clipboard, so the "+ and "* registers are
" supplied through +clipboard_provider. This is Vim's API, not Neovim's: it
" takes v:clipproviders with Vimscript callbacks plus a 'clipmethod' entry, and
" ignores a g:clipboard dict silently.
if exists('v:clipproviders')

  " Backends in preference order, the first whose binary is present winning.
  " WSLg bridges its Wayland and X11 selections to the Windows clipboard, so a
  " local helper round-trips in single-digit milliseconds where spawning a
  " Windows process costs roughly 65ms to copy and 320ms to paste.
  "
  " 'eol' joins the lines of a copied register. WSLg converts LF to CRLF itself
  " when handing a selection to Windows, so only clip.exe is fed CRLF; CRLF sent
  " through a local helper arrives on the Windows side as CR CR LF.
  "
  " Each 'paste' command has to emit the clipboard verbatim, because a trailing
  " newline is the only thing separating a copied line from a copied word.
  " wl-paste needs --no-newline, and Get-Clipboard is written through
  " [Console]::Out.Write because the default pipeline output appends CRLF
  " unconditionally. That call leaves [Console]::OutputEncoding alone: forcing it
  " to UTF-8 is the usual advice and it double-encodes, arriving as caf<box>®.
  let s:clip_backends = [
        \ {'bin': 'wl-copy',
        \  'copy': 'wl-copy',
        \  'paste': 'wl-paste --no-newline',
        \  'eol': "\n",
        \  'islocal': v:true},
        \ {'bin': 'xclip',
        \  'copy': 'xclip -selection clipboard -in',
        \  'paste': 'xclip -selection clipboard -out',
        \  'eol': "\n",
        \  'islocal': v:true},
        \ {'bin': 'clip.exe',
        \  'copy': 'clip.exe',
        \  'paste': 'powershell.exe -NoProfile -NoLogo -Command "[Console]::Out.Write((Get-Clipboard -Raw))"',
        \  'eol': "\r\n",
        \  'islocal': v:false},
        \ ]

  " Resolved once at startup rather than per call: 'clipboard' below routes every
  " yank and delete through these callbacks, and executable() walks $PATH.
  let s:clip_backend = {}
  for s:candidate in s:clip_backends
    if executable(s:candidate.bin)
      let s:clip_backend = s:candidate
      break
    endif
  endfor
  unlet! s:candidate

  func! s:ClipAvailable() abort
    return !empty(s:clip_backend)
  endfunc

  " reg is "+ or "*, type is a getregtype() value, lines is a list of strings.
  func! s:ClipCopy(reg, type, lines) abort
    let l:text = join(a:lines, s:clip_backend.eol)
    if a:type ==# 'V'
      let l:text .= s:clip_backend.eol
    endif
    call system(s:clip_backend.copy, l:text)
  endfunc

  " Returns [regtype, lines]. A trailing newline marks a linewise copy; without
  " one the text came from inside a line. Returning an empty regtype instead
  " would leave the choice to Vim, which guesses linewise for a list of strings
  " and so pastes a copied word onto a line of its own.
  func! s:ClipPaste(reg) abort
    let l:raw = substitute(system(s:clip_backend.paste), "\r", '', 'g')
    if l:raw =~# "\n$"
      return ['V', split(substitute(l:raw, "\n$", '', ''), "\n", 1)]
    endif
    return ['v', split(l:raw, "\n", 1)]
  endfunc

  " Degraded clipboard states are announced rather than left to be discovered by
  " a yank that silently goes nowhere.
  func! s:ClipWarn(msg) abort
    echohl WarningMsg
    echomsg 'clipboard: ' . a:msg
    echohl NONE
  endfunc

  if s:ClipAvailable()
    let v:clipproviders['wsl'] = {
          \   'available': function('s:ClipAvailable'),
          \   'copy':  {'+': function('s:ClipCopy'),  '*': function('s:ClipCopy')},
          \   'paste': {'+': function('s:ClipPaste'), '*': function('s:ClipPaste')},
          \ }
    set clipmethod^=wsl

    " Every yank, delete and change reaches the Windows clipboard, with no leader
    " prefix needed. Gated on a local backend because the Windows process would
    " otherwise put its startup cost on each one, including every x and dd.
    if s:clip_backend.islocal
      set clipboard=unnamedplus
    else
      call s:ClipWarn('no local helper, plain yank stays local (install xclip)')
    endif
  else
    call s:ClipWarn('no backend found, the + and * registers are unavailable')
  endif
endif

" --- netrw ---
" The file explorer. :Lexplore opens it in a side split, and directory buffers
" route here too.
let g:netrw_banner = 0
let g:netrw_liststyle = 3         " tree view
let g:netrw_winsize = 22
let g:netrw_altv = 1

" --- Plugins ---
" Installed as native packages under ~/.vim/pack/plugins/start. Those load
" after this file is sourced, so the g: variables below are read in time.

" ctrlp.vim: fuzzy finder over files, buffers and MRU.
let g:ctrlp_working_path_mode = 'ra' " root at the nearest ancestor holding .git
let g:ctrlp_show_hidden = 1
" Open the selection here rather than jumping to a window already showing it.
let g:ctrlp_switch_buffer = 0
" ripgrep honours .gitignore and is fast enough that caching only adds staleness.
if executable('rg')
  let g:ctrlp_user_command = 'rg --files --hidden --glob "!.git/*" %s'
  let g:ctrlp_use_caching = 0
endif

" The stock statusline spells its mode slider in ASCII (<mru>={files}=<buf>),
" which a ligature font fuses into unrelated glyphs. This replacement shows the
" active mode and the search root unconditionally, and the remaining state only
" while it differs from the default. Both functions must be global: ctrlp calls
" them by name from its own script scope, where s: names do not resolve.
" Highlight groups are shared with the main statusline so the two bars match.
function! CtrlPStatusMain(focus, byfname, regex, prev, item, next, marked) abort
  let l:flags = []
  if a:byfname ==# 'file'
    call add(l:flags, 'filename')
  endif
  if a:regex
    call add(l:flags, 'regex')
  endif
  " ctrlp preformats this argument, passing ' <->' when the selection is empty.
  if a:marked !=# ' <->'
    call add(l:flags, trim(a:marked, ' <>') . ' marked')
  endif

  let l:dir = fnamemodify(getcwd(), ':~')
  if strlen(l:dir) > 45
    let l:dir = pathshorten(l:dir)
  endif

  return '%#StlNormal# ' . a:item . ' '
        \ . (empty(l:flags) ? '' : '%#StlFile# ' . join(l:flags, ', ') . ' ')
        \ . '%#StlFill#%='
        \ . '%#StlPos# ' . l:dir . ' '
endfunction

" Second statusline, shown while the file list is still being scanned.
function! CtrlPStatusProg(str) abort
  return '%#StlCommand# scanning %#StlFile# ' . a:str . ' %#StlFill#%='
endfunction

let g:ctrlp_status_func = {
      \   'main': 'CtrlPStatusMain',
      \   'prog': 'CtrlPStatusProg',
      \ }

" ack.vim: project-wide search into the quickfix list. The plugin aborts at
" load time unless g:ackprg names an available binary, and neither ack nor
" ack-grep is installed, so ripgrep is pointed at it in their place.
if executable('rg')
  let g:ackprg = 'rg --vimgrep --smart-case'
  " The builtin :grep otherwise shells out to system grep, which walks
  " .git and ignores .gitignore.
  set grepprg=rg\ --no-heading\ --vimgrep
  set grepformat=%f:%l:%c:%m
endif
let g:ack_use_cword_for_empty_search = 1

" Vim's bundled markdown syntax highlights fenced blocks only for the languages
" named here, and conceals link and emphasis markup unless told otherwise.
let g:markdown_fenced_languages = [
      \ 'bash=sh',
      \ 'c',
      \ 'cpp',
      \ 'json',
      \ 'python',
      \ 'rust',
      \ 'vim',
      \ 'yaml',
      \ ]
let g:markdown_syntax_conceal = 0

" --- Functions ---

" Run a register's macro over every line of a visual selection. Applying a macro
" with a count stops at the first line where it fails; this does not. Mapped in
" the key mappings section below.
function! s:MacroOverVisualRange() abort
  echo '@' . getcmdline()
  execute ":'<,'>normal @" . nr2char(getchar())
endfunction

" Expand one window to fill the tab and restore the previous layout on the next
" call, the equivalent of tmux's prefix-z. winrestcmd() returns the :resize
" commands that rebuild the current layout, so restoring is replaying them.
" Leaving the zoomed window unzooms, otherwise the stored layout goes stale.
function! s:ToggleZoom(explicit) abort
  if exists('t:zoom_restore') && (t:zoom_restore.win != winnr() || a:explicit)
    execute t:zoom_restore.cmd
    unlet t:zoom_restore
  elseif a:explicit
    let t:zoom_restore = { 'win': winnr(), 'cmd': winrestcmd() }
    vertical resize | resize
  endif
endfunction

augroup restore_zoom
  autocmd!
  autocmd WinEnter * silent! call s:ToggleZoom(v:false)
augroup END

" --- Statusline ---
let s:stl_modes = {
      \ 'n':      ['NORMAL',  'StlNormal'],
      \ 'no':     ['PENDING', 'StlNormal'],
      \ 'i':      ['INSERT',  'StlInsert'],
      \ 'ic':     ['INSERT',  'StlInsert'],
      \ 'v':      ['VISUAL',  'StlVisual'],
      \ 'V':      ['V-LINE',  'StlVisual'],
      \ "\<C-v>": ['V-BLOCK', 'StlVisual'],
      \ 's':      ['SELECT',  'StlVisual'],
      \ 'S':      ['S-LINE',  'StlVisual'],
      \ 'R':      ['REPLACE', 'StlReplace'],
      \ 'Rv':     ['V-REPL',  'StlReplace'],
      \ 'c':      ['COMMAND', 'StlCommand'],
      \ 'cv':     ['EX',      'StlCommand'],
      \ 'r':      ['PROMPT',  'StlCommand'],
      \ 't':      ['TERMINAL','StlCommand'],
      \ }

function! StlMode() abort
  let l:e = get(s:stl_modes, mode(), [toupper(mode()), 'StlNormal'])
  return '%#' . l:e[1] . '# ' . l:e[0] . ' %#StlFile# '
endfunction

" Path relative to cwd or ~, abbreviated past 45 characters so the mode
" indicator is never truncated off the front of the line.
function! StlPath() abort
  let l:p = expand('%:~:.')
  if empty(l:p)
    return '[No Name]'
  endif
  return strlen(l:p) > 45 ? pathshorten(l:p) : l:p
endfunction

" Assigned as a single string; 'set statusline+=' requires escaping every space.
let &statusline =
      \   '%{%StlMode()%}'
      \ . '%{StlPath()} %m%r%h%w'
      \ . '%#StlFill#%='
      \ . '%#StlInfo# %{&filetype ==# "" ? "none" : &filetype} '
      \ . '%#StlInfo#%{&fileencoding ==# "" ? &encoding : &fileencoding} '
      \ . '%#StlPos# %l:%c  %p%% '

" Gruvbox Material palette, reapplied on ColorScheme so the groups survive a
" :colorscheme change.
function! s:StatuslineHighlights() abort
  highlight StlNormal  guibg=#a9b665 guifg=#282828 gui=bold cterm=bold
  highlight StlInsert  guibg=#7daea3 guifg=#282828 gui=bold cterm=bold
  highlight StlVisual  guibg=#d3869b guifg=#282828 gui=bold cterm=bold
  highlight StlReplace guibg=#ea6962 guifg=#282828 gui=bold cterm=bold
  highlight StlCommand guibg=#d8a657 guifg=#282828 gui=bold cterm=bold
  highlight StlFile    guibg=#45403d guifg=#d4be98 gui=NONE   cterm=NONE
  highlight StlFill    guibg=#32302f guifg=#7c6f64 gui=NONE   cterm=NONE
  highlight StlInfo    guibg=#45403d guifg=#d4be98 gui=NONE   cterm=NONE
  highlight StlPos     guibg=#89b482 guifg=#282828 gui=bold cterm=bold
endfunction

augroup statusline_colors
  autocmd!
  autocmd ColorScheme * call s:StatuslineHighlights()
augroup END
call s:StatuslineHighlights()

" --- Key mappings ---
let mapleader = " "
let maplocalleader = " "

" Q drops into Ex mode, which is reached far more often by mistyping :q than on
" purpose. gQ still gets there.
nnoremap Q <Nop>

" Write a file opened without the privileges to save it, by piping the buffer
" through tee instead of letting the edit be lost.
command! -nargs=0 Sudow write !sudo tee % >/dev/null

" Files
nnoremap <leader>w :write<CR>
nnoremap <leader>q :quit<CR>
nnoremap <leader>e :Lexplore<CR>
nnoremap <leader>f :find<Space>

" Project search. The bang leaves the cursor in the current window rather than
" jumping to the first match. An empty pattern searches the word under the cursor.
nnoremap <leader>a :Ack!<Space>
nnoremap <leader>A :Ack!<CR>

" Clear search highlight
nnoremap <silent> <leader><Space> :nohlsearch<CR>

" Zoom the current window to fill the tab, and back
nnoremap <silent> <leader>z :call <SID>ToggleZoom(v:true)<CR>

" System clipboard
nnoremap <leader>y "+y
nnoremap <leader>Y "+y$
xnoremap <leader>y "+y
nnoremap <leader>p "+p
nnoremap <leader>P "+P
xnoremap <leader>p "+p

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize windows with arrows
nnoremap <silent> <Up>    :resize +2<CR>
nnoremap <silent> <Down>  :resize -2<CR>
nnoremap <silent> <Left>  :vertical resize -2<CR>
nnoremap <silent> <Right> :vertical resize +2<CR>

" Keep the cursor centered when jumping through search results and half-pages
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap <silent> *  *zz
nnoremap <silent> #  #zz
nnoremap <silent> g* g*zz
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
" A terminal sends the same byte for <C-i> and <Tab>, so this remaps normal-mode
" <Tab> too. That key is already jump-forward, so the behaviour is unchanged.
nnoremap <C-o> <C-o>zz
nnoremap <C-i> <C-i>zz

" Keep the selection after shifting, allowing repeated indent
xnoremap < <gv
xnoremap > >gv

" Move the selected lines up and down
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv

" Apply a macro to every line of the selection
xnoremap @ :<C-u>call <SID>MacroOverVisualRange()<CR>

" Buffer switching
nnoremap <leader>bb <C-^>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bl :buffers<CR>:buffer<Space>
