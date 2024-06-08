" Filename: .vimrc
" Purpose: Configuration file for Vim, setting up the environment, key bindings, and plugins.

" Ensure compatibility with older versions
set nocompatible

" Pathogen initialization ------------------------------------------------ {{{
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()
filetype plugin indent on
syntax on
" }}}

" Basic options ----------------------------------------------------------- {{{
" General appearance and behavior settings
set t_Co=256
set encoding=utf-8
set modelines=0
set autoindent
set showmode
set showcmd
set hidden
set visualbell
set cursorline
set ttyfast
set ruler
set backspace=indent,eol,start
set nonumber
set norelativenumber
set laststatus=2
set history=1000
set undofile
set undoreload=10000
set cpoptions+=J
set listchars=tab:▸\ ,eol:¬,extends:❯,precedes:❮
set shell=/bin/zsh
set lazyredraw
set matchtime=3
set splitbelow
set splitright
set fillchars=diff:\ 
set ttimeout
set notimeout
set nottimeout
set autowrite
set shiftround
set autoread
set title 
set titleold="" 
set titlestring=VIM:\ %F 
set dictionary=/usr/share/dict/words
set viminfo='100,n$HOME/.vim/viminfo
" }}}

" Git commit settings ---------------------------------------------------- {{{
augroup gitcommit_settings
    autocmd!
    autocmd FileType gitcommit setlocal textwidth=100
augroup END
" }}}

" Split and tab settings ------------------------------------------------- {{{
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set wrap
set textwidth=80
set formatoptions=qrn1
set undodir=~/.vim/tmp/undo//     " undo files
set backupdir=~/.vim/tmp/backup// " backups
set directory=~/.vim/tmp/swap//   " swap files
set backup                        " enable backups
" }}}

" Key mappings ----------------------------------------------------------- {{{
let mapleader = ","
map <D-1> 1gt
map <D-2> 2gt
map <D-3> 3gt
map <D-4> 4gt
map <D-5> 5gt
map <D-6> 6gt
map <D-7> 7gt
map <D-8> 8gt
map <D-9> 9gt
map <D-0> :tablast<CR>
map <leader>tt :tabnew<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
map <leader>tn :tabnext<cr>
map <leader>tp :tabprevious<cr>
" }}}

" Syntax and color settings ---------------------------------------------- {{{
syntax on
set background=dark
colorscheme hemisu

" Highlight VCS conflict markers
match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'
" }}}

" Statusline customization ----------------------------------------------- {{{
augroup ft_statuslinecolor
    au!
    au InsertEnter * hi StatusLine ctermfg=196 guifg=#FF3145
    au InsertLeave * hi StatusLine ctermfg=130 guifg=#CD5907
augroup END

" Statusline configuration
set statusline=%f    " Path.
set statusline+=%m   " Modified flag.
set statusline+=%r   " Readonly flag.
set statusline+=%w   " Preview window flag.
set statusline+=\    " Space.
set statusline+=%#redbar#                " Highlight the following as a warning.
set statusline+=%{SyntasticStatuslineFlag()} " Syntastic errors.
set statusline+=%*                           " Reset highlighting.
set statusline+=%=   " Right align.
set statusline+=(    " File format, encoding and type: (unix/utf-8/python)"
set statusline+=%{&ff}/%{strlen(&fenc)?&fenc:&enc}/%{&ft}                        "
set statusline+=)    " Line and column position and counts: (line %l/%L, col %03c)"
" }}}

" Searching and movement settings ---------------------------------------- {{{
set ignorecase
set smartcase
set incsearch
set showmatch
set hlsearch
set gdefault
" Use sane regexes.
nnoremap / /
vnoremap / /
" }}}

" Python development settings -------------------------------------------- {{{
augroup ft_python
    au!
    autocmd BufNewFile,BufRead *.cinc set syntax=python
    autocmd BufNewFile,BufRead *.mcconf set syntax=python
    au Filetype python noremap  <buffer> <localleader>rr :RopeRename<CR>
    au Filetype python vnoremap <buffer> <localleader>rm :RopeExtractMethod<CR>
    au Filetype python noremap  <buffer> <localleader>ri :RopeOrganizeImports<CR>
    au FileType python setlocal omnifunc=pythoncomplete#Complete
    au FileType python setlocal define=^\s*\(def\\|class\)
    au FileType man nnoremap <buffer> <cr> :q<cr>
augroup END
" }}}

" Toggle paste
set pastetoggle=<F8>

" Environments (GUI/Console) settings ------------------------------------ {{{
let g:Powerline_symbols = 'fancy'
let g:airline_powerline_fonts = 1
if has('gui_running')
    " GUI-specific settings
    set guifont=Inconsolata\ for\ Powerline\ Medium\ 12
    highlight SpellBad term=underline gui=undercurl guisp=Orange
    set fillchars+=vert:│
    if has("gui_macvim")
        set fuoptions=maxvert,maxhorz
        let macvim_skip_cmd_opt_movement = 1
        no   <D-Left>       <Home>
        no!  <D-Left>       <Home>
        no   <M-Left>       <C-Left>
        no!  <M-Left>       <C-Left>
        no   <D-Right>      <End>
        no!  <D-Right>      <End>
        no   <M-Right>      <C-Right>
        no!  <M-Right>      <C-Right>
        no   <D-Up>         <C-Home>
        ino  <D-Up>         <C-Home>
        imap <M-Up>         <C-o>{
        no   <D-Down>       <C-End>
        ino  <D-Down>       <C-End>
        imap <M-Down>       <C-o>}
        imap <M-BS>         <C-w>
        inoremap <D-BS>     <esc>my0c`y
    else
        " Non-MacVim GUI, like Gvim
    endif
else
    " Console Vim settings
endif
" }}}
