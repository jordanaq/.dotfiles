for _, name in ipairs(require("dotfiles.settings").mini.modules) do
  local module = require("mini." .. name)
  module.setup()
  if name == "icons" then
    module.mock_nvim_web_devicons()
  end
end
