vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false

vim.opt.smartindent = true

vim.opt.wrap = true 

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50

vim.cmd [[ hi Search ctermbg=LightYellow ctermfg=Red ]]

vim.g.mapleader = " "

vim.g.netrw_sort_sequence = "[\\/]$,\\<core\\%(\\.\\d\\+\\)\\=\\>"

vim.api.nvim_create_autocmd('TextYankPost', {
	desc = 'Auto highlight yanked text',
	group = vim.api.nvim_create_augroup('highlight_yank', {clear=true}),
	callback = function()
		vim.highlight.on_yank()
	end,
})
