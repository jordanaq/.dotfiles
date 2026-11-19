local conform = require("conform")

conform.setup(require("dotfiles.settings").conform)

local function format_buffer()
  conform.format({ async = true, lsp_format = "fallback" })
end

vim.api.nvim_create_user_command("Format", format_buffer, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>cf", format_buffer, { desc = "Format buffer" })
