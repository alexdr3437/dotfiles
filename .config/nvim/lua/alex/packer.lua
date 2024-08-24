-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
	use 'wbthomason/packer.nvim'

	-- fuzzy find
	use {
		'nvim-telescope/telescope.nvim', tag = '0.1.3',
		-- or                            , branch = '0.1.x',
		requires = { { 'nvim-lua/plenary.nvim' }, { 'nvim-telescope/telescope-fzf-native.nvim' } }

	}

	-- colorscheme
	use "rebelot/kanagawa.nvim"
	use "catppuccin/nvim"
	use "Mofiqul/dracula.nvim"

	-- minimap
	use { 'echasnovski/mini.nvim', branch = 'stable' }

	-- parsing
	use {
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate'
	}

	-- text manipulation
	use "vim-scripts/argtextobj.vim"
	use "michaeljsmith/vim-indent-object"
	use "terrortylor/nvim-comment"
	use {
		"windwp/nvim-autopairs",
		config = function() require("nvim-autopairs").setup {} end
	}
	use "ahonn/vim-fileheader"
	use({
		"kylechui/nvim-surround",
		tag = "*", -- Use for stability; omit to use `main` branch for the latest features
		config = function()
			require("nvim-surround").setup({
				-- Configuration here, or leave empty to use defaults
			})
		end
	})

	-- TODO kfjdsaf
	use { 'folke/todo-comments.nvim',		
		requires = 'nvim-lua/plenary.nvim',
		config = function() require('todo-comments').setup {signs = true} end
	}
	


	-- file navigation
	use "nvim-lua/plenary.nvim" -- don't forget to add this one if you don't have it yet!
	use {
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		requires = { { "nvim-lua/plenary.nvim" } }
	}

	use {
		"stevearc/oil.nvim",
		config = function()
			require("oil").setup()
		end
	}

	-- file  manipulation
	use('mbbill/undotree')

	-- git
	use('tpope/vim-fugitive')

	-- lsp, linting, formatting


	use {
		'VonHeikemen/lsp-zero.nvim',
		branch = 'v3.x',
		requires = {
			--- Uncomment these if you want to manage LSP servers from neovim
			{ 'williamboman/mason.nvim' },
			{ 'williamboman/mason-lspconfig.nvim' },

			-- LSP Support
			{ 'neovim/nvim-lspconfig' },
			-- Autocompletion
			{ 'hrsh7th/nvim-cmp' },
			{ 'hrsh7th/cmp-nvim-lsp' },
			{ 'L3MON4D3/LuaSnip' },
		}
	}

	use "simonrw/vim-yapf"

	-- tasks
	use {
		'EthanJWright/vs-tasks.nvim',
		requires = {
			'nvim-lua/popup.nvim',
			'nvim-lua/plenary.nvim',
			'nvim-telescope/telescope.nvim'
		}
	}

	-- tmux
	use 'christoomey/vim-tmux-navigator'

	-- get good
	use 'ThePrimeagen/vim-be-good'


	-- copilot
	use 'github/copilot.vim'
	use 'CopilotC-Nvim/CopilotChat.nvim'
end)
