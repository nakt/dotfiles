set number
set showcmd
set showmatch
set hlsearch
set cursorline
set autoindent
set expandtab
set tabstop=2
set shiftwidth=2
set incsearch
set ignorecase
set smartcase
set notimeout
set ttimeout
set timeoutlen=100
set backspace=indent,eol,start

filetype on
syntax enable
autocmd FileType make setlocal noexpandtab
autocmd BufWritePre * :%s/\s\+$//ge
nnoremap <ESC><ESC> :nohlsearch<CR>

" ペースト時のインデントを合わせる
nnoremap p ]p
nnoremap ]p p
" 検索後に画面中央に移動
nnoremap n nzz
nnoremap N Nzz
nnoremap * *zz
" TABにて対応ペアにジャンプ
nnoremap <Tab> %
vnoremap <Tab> %

let mapleader = "\<Space>"
