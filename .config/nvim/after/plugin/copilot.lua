local copilot_chat = require("CopilotChat")
copilot_chat.setup({
	debug = false,           -- Enable or disable debug mode
	show_help = 'yes',       -- Show help text for CopilotChatInPlace
	disable_extra_info = 'no', -- Disable extra information in the response
	hide_system_prompt = 'yes', -- Hide system prompts in the response
	proxy = '',              -- Proxies requests via https or socks
	prompts = {              -- Set dynamic prompts for CopilotChat commands
		Explain = 'Explain how it works.',
		Tests = 'Briefly explain how the selected code works, then generate unit tests.',
	},
	temperature = 0.1, -- Set the temperature for CopExplainilotChat
})

vim.keymap.set('n', '<leader>ie', "<cmd>CopilotChatExplain<cr>")
vim.keymap.set('n', '<leader>ic', function()
	vim.ui.input({ prompt = "CopilotChat: " }, function(inp) vim.cmd("CopilotChat " .. inp) end)
end)
vim.keymap.set('n', '<leader>iv', "<cmd>CopilotChatVsplitToggle<cr>")

-- Copilot keymaps
vim.api.nvim_set_keymap("i", "<C-y>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
vim.api.nvim_set_keymap("i", "<C-h>", 'copilot#Previous()', { silent = true, expr = true })
vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Next()', { silent = true, expr = true })
