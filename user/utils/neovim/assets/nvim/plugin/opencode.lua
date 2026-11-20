local command = { "opencode" }
local terminal = {
  win = { position = "right", enter = false },
}

vim.g.opencode_opts = {
  server = {
    start = function()
      Snacks.terminal.open(command, terminal)
    end,
  },
}

vim.keymap.set("n", "<leader>ot", function()
  Snacks.terminal.toggle(command, terminal)
end, { desc = "Toggle OpenCode" })
vim.keymap.set({ "n", "x" }, "<leader>oa", function()
  require("opencode").ask("@this: ")
end, { desc = "Ask OpenCode" })
vim.keymap.set({ "n", "x" }, "<leader>ox", function()
  require("opencode").select()
end, { desc = "OpenCode actions" })
vim.keymap.set({ "n", "x" }, "go", function()
  return require("opencode").operator("@this")
end, { desc = "Send range to OpenCode", expr = true })
vim.keymap.set("n", "goo", function()
  return require("opencode").operator("@this") .. "_"
end, { desc = "Send line to OpenCode", expr = true })
