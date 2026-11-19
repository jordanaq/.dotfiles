local path = vim.fn.stdpath("config") .. "/dotfiles-settings.json"
return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
