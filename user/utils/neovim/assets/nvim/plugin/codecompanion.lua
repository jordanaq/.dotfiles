local adapters = require("codecompanion.adapters")
local codecompanion_settings = require("dotfiles.settings").codecompanion
local adapter = codecompanion_settings.adapter

require("codecompanion").setup({
  display = { chat = { window = codecompanion_settings.chatWindow } },
  adapters = {
    [adapter.name] = function()
      return adapters.extend(adapter.name, {
        env = codecompanion_settings.env,
        schema = {
          model = { default = adapter.model },
          choices = { adapter.model },
        },
      })
    end,
  },
  interactions = {
    chat = { adapter = vim.deepcopy(adapter) },
    inline = { adapter = vim.deepcopy(adapter) },
    background = { adapter = vim.deepcopy(adapter) },
  },
})

vim.keymap.set({ "n", "v" }, "<leader>aa", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "AI chat" })
vim.keymap.set("v", "<leader>ae", ":CodeCompanion ", { desc = "AI edit selection" })
vim.keymap.set("n", "<leader>aA", function()
  vim.ui.input({ prompt = "Agent task: " }, function(input)
    if input and input ~= "" then
      vim.api.nvim_cmd({
        cmd = "CodeCompanionChat",
        args = { "adapter=" .. adapter.name, "model=" .. adapter.model, "@{agent} " .. input },
      }, {})
    end
  end)
end, { desc = "AI agent task" })
