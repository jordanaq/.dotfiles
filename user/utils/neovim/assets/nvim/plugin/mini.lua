local mini_settings = require("dotfiles.settings").mini

for _, name in ipairs(mini_settings.modules) do
  local module = require("mini." .. name)
  local opts
  if name == "ai" then
    opts = { custom_textobjects = vim.tbl_map(module.gen_spec.treesitter, mini_settings.textobjects) }
  end
  module.setup(opts)
  if name == "icons" then
    module.mock_nvim_web_devicons()
  end
end
