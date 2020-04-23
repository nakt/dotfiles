let s:plug_dir = expand('~/.vim/autoload')

if !isdirectory(s:plug_dir)
  execute '!curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

call plug#begin()
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
Plug 'arcticicestudio/nord-vim'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'
Plug 'rhysd/vim-operator-surround'
Plug 'kana/vim-operator-user'
Plug 'jmcantrell/vim-virtualenv'
Plug 'hashivim/vim-terraform'
Plug 'simeji/winresizer'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'preservim/nerdtree'
Plug 'mechatroner/rainbow_csv'
call plug#end()
