require("flash").setup({})
-- Avoid mapping 's' because mini.surround uses 'sa', 'sd', and 'sr'.
vim.keymap.set({ "n", "x", "o" }, "<leader>j", function()
  require("flash").jump()
end, { desc = "Flash jump" })
vim.keymap.set({ "n", "x", "o" }, "<leader>J", function()
  require("flash").treesitter()
end, { desc = "Flash syntax selection" })
