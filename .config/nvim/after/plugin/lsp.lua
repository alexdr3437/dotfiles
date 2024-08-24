local lsp_zero = require('lsp-zero')

lsp_zero.on_attach(function(client, bufnr)
    lsp_zero.default_keymaps({ buffer = bufnr })
    -- see :help lsp-zero-keybindings
    -- to learn the available actions
end)

require('lspconfig').lua_ls.setup({
    settings = {
        Lua = {
            diagnostics = {
                globals = { 'vim' }
            }
        }
    }
})

require 'lspconfig'.rust_analyzer.setup {}
require 'lspconfig'.clangd.setup {}

require('nvim_comment').setup()
