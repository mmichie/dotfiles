" Minimal .vimrc for basic editing
" No plugins, no complex configurations

" Basic Settings ---------------------------------------------------------- {{{
set nocompatible
set encoding=utf-8
set modelines=0

" General appearance and behavior
set showmode
set showcmd
set hidden
set visualbell
set cursorline
set ruler
set number
set laststatus=2
set backspace=indent,eol,start
set history=500

" Splits and Windows
set splitbelow
set splitright

" Basic indentation without plugins
set autoindent
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set wrap
set textwidth=80
set formatoptions=qrn1

" Search settings
set ignorecase
set smartcase
set incsearch
set showmatch
set hlsearch
" }}}

" Basic File Management --------------------------------------------------- {{{
" Create backup/undo/swap directories if they don't exist
if !isdirectory($HOME.'/.vim/backup')
    silent! call mkdir($HOME.'/.vim/backup', 'p')
endif
if !isdirectory($HOME.'/.vim/undo')
    silent! call mkdir($HOME.'/.vim/undo', 'p')
endif
if !isdirectory($HOME.'/.vim/swap')
    silent! call mkdir($HOME.'/.vim/swap', 'p')
endif

set undodir=$HOME/.vim/undo//
set backupdir=$HOME/.vim/backup//
set directory=$HOME/.vim/swap//
set backup
set undofile
" }}}

" Key Mappings ----------------------------------------------------------- {{{
" Set leader key
let mapleader = ","

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Tab management
nnoremap <leader>tt :tabnew<cr>
nnoremap <leader>tc :tabclose<cr>
nnoremap <leader>tn :tabnext<cr>
nnoremap <leader>tp :tabprevious<cr>

" Clear search highlighting
nnoremap <leader><space> :noh<cr>

" Toggle paste mode
set pastetoggle=<F2>
" }}}

" Basic Autocommands ----------------------------------------------------- {{{
if has("autocmd")
    " Enable file type detection
    filetype on
    filetype plugin on
    filetype indent on

    " When editing a file, always jump to the last known cursor position
    autocmd BufReadPost *
        \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
        \ |   exe "normal! g`\""
        \ | endif

    " Git commit messages
    autocmd FileType gitcommit setlocal textwidth=72

    " Automatically remove trailing whitespace
    autocmd BufWritePre * :%s/\s\+$//e
endif
" }}}

" Basic Statusline ------------------------------------------------------- {{{
set statusline=%f                            " File path
set statusline+=%m                           " Modified flag
set statusline+=%r                           " Readonly flag
set statusline+=%=                           " Switch to right side
set statusline+=%y                           " File type
set statusline+=[%{&fileformat}]             " File format
set statusline+=[%{strlen(&fenc)?&fenc:&enc}] " File encoding
set statusline+=[%l/%L]                      " Current line/Total lines
" }}}

" Basic Color Settings --------------------------------------------------- {{{
syntax enable
set background=dark
" Use a basic colorscheme that's available everywhere
colorscheme desert
" }}}
