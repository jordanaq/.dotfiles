local settings = require("dotfiles.settings")

for name, value in pairs(settings.editor.globals) do
  vim.g[name] = value
end
for name, value in pairs(settings.editor.options) do
  vim.o[name] = value
end

vim.cmd.colorscheme(settings.colorscheme)
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { noremap = true, silent = true })

vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
vim.filetype.add(settings.editor.filetypes)

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank(settings.editor.yankHighlight)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = settings.editor.cIndent.filetypes,
  callback = function(event)
    for name, value in pairs(settings.editor.cIndent.options) do
      vim.bo[event.buf][name] = value
    end
  end,
})
