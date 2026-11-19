require("snacks").setup(require("dotfiles.settings").snacks)

local map = function(keys, fn, desc)
  vim.keymap.set("n", keys, fn, { desc = desc })
end

map("<leader>e", function() Snacks.explorer() end, "File explorer")
map("<leader>ff", function() Snacks.picker.files() end, "Find files")
map("<leader>fg", function() Snacks.picker.grep() end, "Search project text")
map("<leader>fb", function() Snacks.picker.buffers() end, "Find buffers")
map("<leader>fh", function() Snacks.picker.help() end, "Find help")
