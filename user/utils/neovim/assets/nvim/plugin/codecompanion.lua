local adapters = require("codecompanion.adapters")

require("codecompanion").setup({
  display = {
    chat = {
      window = {
        layout = "vertical",
        position = "right",
      },
    },
  },
  adapters = {
    http = {
      ollama = function()
        return adapters.extend("ollama", {
          env = {
            url = "http://127.0.0.1:11434",
          },
          schema = {
            model = {
              default = "qwen2.5-coder:14b",
            },
            choices = {
              "qwen2.5-coder:14b",
              "gemma4:12b",
              "gemma4:e4b",
              "gpt-oss:20b",
            },
            num_ctx = {
              default = 32768,
            },
            temperature = {
              default = 0.2,
            },
          },
        })
      end,
    },
  },
  interactions = {
    chat = {
      adapter = {
        name = "ollama",
        model = "qwen2.5-coder:14b",
      },
    },
    inline = {
      adapter = {
        name = "ollama",
        model = "qwen2.5-coder:14b",
      },
    },
    background = {
      adapter = {
        name = "ollama",
        model = "gemma4:e4b",
      },
    },
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
        args = { "adapter=ollama", "model=gemma4:12b", "@{agent} " .. input },
      }, {})
    end
  end)
end, { desc = "AI agent task" })
