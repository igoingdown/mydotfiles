"=====================开始安装插件===========================================
set nocompatible               " be iMproved
let mapleader=","              " change the leader to be a comma vs slash
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#rc()

" let Vundle manage Vundle
" required!

Bundle 'VundleVim/Vundle.vim'
Bundle 'scrooloose/nerdtree'
Bundle 'jistr/vim-nerdtree-tabs'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Bundle 'davidhalter/jedi-vim'
Bundle 'tpope/vim-fugitive'
Bundle 'wincent/Command-T'
Bundle 'jnwhiteh/vim-golang'
Bundle 'ervandew/supertab'
Bundle 'yann2192/vim-colorschemes'
Bundle 'yann2192/vim-vitamins'
Bundle 'fatih/vim-go'
Bundle 'scrooloose/syntastic'

" Snipmate
Bundle 'tomtom/tlib_vim'
Bundle 'MarcWeber/vim-addon-mw-utils'
Bundle 'garbas/vim-snipmate'

Plugin 'jiangmiao/auto-pairs'
Plugin 'majutsushi/tagbar'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
"Plugin 'Valloric/YouCompleteMe'
Plugin 'w0rp/ale'


filetype plugin indent on     " required!


"=============其实就是在保存之后重新载入一下================================
" 设置 vimrc 修改保存后立刻生效，不用在重新打开
" 建议配置完成后将这个关闭
autocmd BufWritePost $MYVIMRC source $MYVIMRC


"==============不知道这个东西有啥用，我先干掉了！============================
" 关闭兼容模式
set nocompatible


"==============不知道这个东西有啥用，我先干掉了！============================
set nu " 设置行号
set cursorline "突出显示当前行
set cursorcolumn " 突出显示当前列
set showmatch " 显示括号匹配


"==============tab 缩进============================
set tabstop=4 " 设置Tab长度为4空格
set shiftwidth=4 " 设置自动缩进长度为4空格
set autoindent " 继承前一行的缩进方式，适用于多行注释


"==============快捷键设置, 我暂时用不到，先干掉============================
" 定义快捷键的前缀，即<Leader>
" let mapleader=";" 


"==============系统剪切板复制粘贴============================
" v 模式下复制内容到系统剪切板
vmap <Leader>c "+yy
" n 模式下复制一行到系统剪切板
nmap <Leader>c "+yy
" n 模式下粘贴系统剪切板的内容
nmap <Leader>v "+p


"==============搜索设置============================
" 开启实时搜索
set incsearch
" 搜索时大小写不敏感
set ignorecase
syntax enable
syntax on                    " 开启文件类型侦测


"==============文件自动保存============================
" 退出插入模式指定类型的文件自动保存
au InsertLeave *.go,*.sh,*.php write


"==============NERDTREE============================
" 自动启动NERDTREE 
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" 在目录栏显示隐藏文件
let NERDTreeShowHidden=1
" open NERDTree with Ctrl+n 
map <C-n> :NERDTreeToggle<CR>

" change default arrows
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'

" Run NERDTreeTabs on console vim startup
let g:nerdtree_tabs_open_on_console_startup=1


"==============Tagbar============================
" 启动Tagbar快捷键
nmap <F8> :TagbarToggle<CR>


"==============AutoPairs============================
" autopairs默认设置
let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutBackInsert = '<M-b>'


"==============airline============================
" airline主题配置默认设置
let g:airline_theme='light'


"==============Font Setting============================
" 配置字体和大小 
set guifont=menlo:h16


"==============ale Setting============================
"let g:ale_fix_on_save = 1
"let g:ale_completion_enabled = 1
"let g:ale_sign_column_always = 1
"let g:airline#extensions#ale#enabled = 1


"==============jedi-vim Setting============================
let g:jedi#completions_command = "<C-B>"


"==============允许将函数和类折叠============================
set foldmethod=indent
set foldlevel=99
