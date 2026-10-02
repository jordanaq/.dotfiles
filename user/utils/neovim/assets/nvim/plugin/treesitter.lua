require("nvim-treesitter").setup()

vim.api.nvim_create_autocmd("FileType", {
  callback = function(event)
    if pcall(vim.treesitter.start, event.buf) then
      vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
