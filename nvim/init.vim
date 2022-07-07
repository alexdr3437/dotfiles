call plug#begin()

Plug 'morhetz/gruvbox'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'pechorin/any-jump.vim'

call plug#end()

colorscheme gruvbox 

" -- leader key
let mapleader = ";"

" -- fzf window
let g:fzf_preview_window = ['up:40%:hidden', 'ctrl-/']

" -- fzf shortcuts
map <leader>f :FZF<CR>
map <leader>r :Rg<CR>

