local persistence = require("persistence")

persistence.setup({})
vim.keymap.set("n", "<leader>qs", function() persistence.load() end, { desc = "Restore project session" })
vim.keymap.set("n", "<leader>qS", persistence.select, { desc = "Select saved session" })
vim.keymap.set("n", "<leader>ql", function() persistence.load({ last = true }) end, { desc = "Restore last session" })
