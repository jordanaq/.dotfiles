local lsp_settings = require("dotfiles.settings")
local capabilities = require("blink.cmp").get_lsp_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
})

-- Open diagnostic float for the line under the cursor
vim.keymap.set("n", "gl", vim.diagnostic.open_float, { desc = "Show diagnostics" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local bufnr = event.buf
    local client = vim.lsp.get_client_by_id(event.data.client_id)

    local function bufmap(keys, func)
      vim.keymap.set("n", keys, func, { buffer = bufnr })
    end

    bufmap("<leader>r", vim.lsp.buf.rename)
    bufmap("<leader>a", vim.lsp.buf.code_action)

    bufmap("gd", vim.lsp.buf.definition)
    bufmap("gD", vim.lsp.buf.declaration)
    bufmap("gI", vim.lsp.buf.implementation)
    bufmap("<leader>D", vim.lsp.buf.type_definition)

    bufmap("gr", function() Snacks.picker.lsp_references() end)
    bufmap("<leader>s", function() Snacks.picker.lsp_symbols() end)
    bufmap("<leader>S", function() Snacks.picker.lsp_workspace_symbols() end)

    bufmap("K", vim.lsp.buf.hover)

    if client and client.name:match("ltex") then
      require("ltex_extra").setup(lsp_settings.ltexExtra)
      -- ltex_extra's reload looks up the client in the current buffer.
      vim.schedule(function()
        if not vim.lsp.buf_is_attached(bufnr, client.id) then
          return
        end
        vim.api.nvim_buf_call(bufnr, function()
          local commands = require("ltex_extra.commands-lsp")
          for _, language in ipairs(lsp_settings.ltexExtra.load_langs) do
            commands.updateConfig("dictionary", language)
            commands.updateConfig("disabledRules", language)
            commands.updateConfig("hiddenFalsePositives", language)
          end
        end)
      end)
    end
  end,
})

local servers = {}
for _, server in ipairs(lsp_settings.lspServers) do
  if server.settings or server.cmd then
    vim.lsp.config(server.name, { settings = server.settings, cmd = server.cmd })
  end
  table.insert(servers, server.name)
end
vim.lsp.enable(servers)
