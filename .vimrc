"=====================配置快捷键的前缀======================================
" 定义快捷键的前缀，即<Leader>
let mapleader=";"


"=====================配色方案======================================
" 配色方案
set background=dark
"colorscheme solarized
" 注意: molokai 由 vim-colorschemes 插件提供，必须等 Vundle 把插件加入 runtimepath
" (call vundle#end / filetype plugin indent on) 之后才能找到，所以实际的 colorscheme
" 设置放在下面插件块之后，见 `silent! colorscheme molokai`。

"colorscheme phd


"=====================开始安装插件===========================================
set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#rc()

" let Vundle manage Vundle
" required!

Bundle 'VundleVim/Vundle.vim'
Bundle "XadillaX/json-formatter.vim"
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
Bundle 'solarnz/thrift.vim'
Bundle 'ruanyl/vim-gh-line'

" Snipmate
Bundle 'tomtom/tlib_vim'
Bundle 'MarcWeber/vim-addon-mw-utils'
Bundle 'garbas/vim-snipmate'

Plugin 'jiangmiao/auto-pairs'
Plugin 'majutsushi/tagbar'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
" Plugin 'Valloric/YouCompleteMe'
Plugin 'mileszs/ack.vim'
Plugin 'w0rp/ale'
Plugin 'sheerun/vim-polyglot'
Plugin 'zivyangll/git-blame.vim'
Plugin 'Vimjas/vim-python-pep8-indent'
Plugin 'kien/rainbow_parentheses.vim'
Plugin 'jspringyc/vim-word'


filetype plugin indent on     " required!

"=====================配色方案（需在插件加载后应用）===========================
" 插件已加入 runtimepath，此时才能找到 molokai；silent! 避免插件缺失时报 E185。
silent! colorscheme molokai


"=====================文件类型侦测设置===========================================
" 开启文件类型侦测
filetype on

" 根据侦测到的不同类型加载对应的插件
" C++ 的语法高亮插件与python 的不同
filetype plugin on


"=============其实就是在保存之后重新载入一下================================
" 设置 vimrc 修改保存后立刻生效，不用在重新打开
" 建议配置完成后将这个关闭
autocmd BufWritePost $MYVIMRC source $MYVIMRC


"=============搜索与补全================================
" 开启实时搜索功能
set incsearch
" 搜索时大小写不敏感
set ignorecase
" vim 自身命令行模式智能补全
set wildmenu


"==============不知道这个东西有啥用============================
" 关闭兼容模式
set nocompatible


"==============设置突出显示============================
set nu " 设置行号
set cursorline "突出显示当前行
" set cursorcolumn " 突出显示当前列
set showmatch " 显示括号匹配


"==============tab 缩进============================
set tabstop=4 " 设置Tab长度为4空格
set shiftwidth=4 " 设置自动缩进长度为4空格
set autoindent " 继承前一行的缩进方式，适用于多行注释
set softtabstop=4   " 使得按退格键时可以一次删掉 4 个空格
set expandtab"


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

" 将nerdtree左侧的目录树显示为高亮
highlight Directory ctermfg=cyan


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
set guifont=menlo:\ 10


"==============ale Setting============================
let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 1
let g:ale_sign_column_always = 1
let g:airline#extensions#ale#enabled = 1


"==============jedi-vim Setting============================
let g:jedi#completions_command = "<C-B>"


"==============允许将函数和类折叠============================
set foldmethod=indent
set foldlevel=99


"==============将注释字体颜色修改为蓝色============================
hi Comment ctermfg=blue


"==============不同的匹配括号用不同的颜色匹配============================
let g:rbpt_colorpairs = [
                        \ ['brown',       'RoyalBlue3'],
                        \ ['Darkblue',    'SeaGreen3'],
                        \ ['darkgray',    'DarkOrchid3'],
                        \ ['darkgreen',   'firebrick3'],
                        \ ['darkcyan',    'RoyalBlue3'],
                        \ ['darkred',     'SeaGreen3'],
                        \ ['darkmagenta', 'DarkOrchid3'],
                        \ ['brown',       'firebrick3'],
                        \ ['gray',        'RoyalBlue3'],
                        \ ['darkmagenta', 'DarkOrchid3'],
                        \ ['Darkblue',    'firebrick3'],
                        \ ['darkgreen',   'RoyalBlue3'],
                        \ ['darkcyan',    'SeaGreen3'],
                        \ ['darkred',     'DarkOrchid3'],
                        \ ['red',         'firebrick3'],
                        \ ]
let g:rbpt_max = 16
let g:rbpt_loadcmd_toggle = 0
au VimEnter * RainbowParenthesesToggle
au Syntax * RainbowParenthesesLoadRound
au Syntax * RainbowParenthesesLoadSquare
au Syntax * RainbowParenthesesLoadBraces


"==============syntastic设置============================
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0


"==============用 ag 代替 ack============================
let g:ackprg = 'ag --nogroup --nocolor --column'


"==============ack 快捷键配置============================
nnoremap √ <C-v>
nnoremap ˙ <C-w>h
nnoremap ∆ <C-w>j
nnoremap ˚ <C-w>k
nnoremap ¬ <C-w>l

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l


"==============git blame 配置============================
nnoremap gb :<C-u>call gitblame#echo()<CR>



"============== browse remote ============================
let g:gh_gitlab_domain = "xxx"


"============== code 折叠与展开配置 ============================
set foldmethod=indent


"============== 复制粘贴配置 ============================
" 仅在 vim 编译了 +clipboard 时设置，否则 -clipboard 的构建会报 E474。
" unnamedplus 还需要 +X11；缺失时退回 unnamed，避免报错。
if has('clipboard')
  if has('unnamedplus')
    set clipboard=unnamedplus,unnamed,autoselect
  else
    set clipboard=unnamed,autoselect
  endif
endif

"=====================走 xclip 的系统剪贴板（-clipboard 构建的兜底）===============
" 这台 vim 是 -clipboard，无法用 "+y / "*y 直接访问系统剪贴板。
" 装了 xclip 时，用外部命令把寄存器内容送入/取出系统剪贴板。
" 仍需可达的 X server（如 ssh -X）；DISPLAY 未设置时只给提示，不报错。
if !has('clipboard') && executable('xclip')
  " 复制：可视模式选中后 <leader>y，把选区(字符/行/块均保留)送进系统剪贴板
  function! s:XclipYank() abort
    if empty($DISPLAY)
      echohl WarningMsg | echo 'xclip: $DISPLAY 未设置（需 ssh -X），已跳过复制' | echohl None
      return
    endif
    call system('xclip -selection clipboard', @z)
  endfunction
  xnoremap <silent> <leader>y "zy:call <SID>XclipYank()<CR>

  " 粘贴：普通模式 <leader>p，从系统剪贴板取内容粘到光标后
  function! s:XclipPaste() abort
    if empty($DISPLAY)
      echohl WarningMsg | echo 'xclip: $DISPLAY 未设置（需 ssh -X），已跳过粘贴' | echohl None
      return
    endif
    let @z = system('xclip -selection clipboard -o')
    normal! "zp
  endfunction
  nnoremap <silent> <leader>p :call <SID>XclipPaste()<CR>
endif



"============== snipmate parser 更新减少warning ============================
let g:snipMate = { 'snippet_version' : 1 }
