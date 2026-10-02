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
    -- OpenAI-compatible adapter pointed at the Nous Portal inference API.
    -- The API key is read from the NOUS_API_KEY env var, which is exported
    -- into the session env from the git-ignored ~/.config/nous/secrets.env
    -- (see gbrain.nix) — the key never lives in the dotfiles repo.
    openai = function()
      return adapters.extend("openai", {
        env = {
          url = "https://inference-api.nousresearch.com/v1",
          api_key_name = "NOUS_API_KEY",
        },
        schema = {
          model = {
            default = "deepseek/deepseek-v4-flash",
          },
          choices = {
            "deepseek/deepseek-v4-flash",
          },
        },
      })
    end,
  },
  interactions = {
    chat = {
      adapter = {
        name = "openai",
        model = "deepseek/deepseek-v4-flash",
      },
    },
    inline = {
      adapter = {
        name = "openai",
        model = "deepseek/deepseek-v4-flash",
      },
    },
    background = {
      adapter = {
        name = "openai",
        model = "deepseek/deepseek-v4-flash",
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
        args = { "adapter=openai", "model=deepseek/deepseek-v4-flash", "@{agent} " .. input },
      }, {})
    end
  end)
end, { desc = "AI agent task" })
