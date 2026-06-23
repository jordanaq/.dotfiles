local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
})

vim.lsp.config("harper_ls", {
  settings = {
    harper_ls = {
      userDictPath = "~/dict.txt",
    },
  },
})

vim.lsp.config("ltex_plus", {
  settings = {
    ltex = {
      checkFrequency = "save",
      language = "en-US",
    },
  },
})

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

    bufmap("gr", require("telescope.builtin").lsp_references)
    bufmap("<leader>s", require("telescope.builtin").lsp_document_symbols)
    bufmap("<leader>S", require("telescope.builtin").lsp_dynamic_workspace_symbols)

    bufmap("K", vim.lsp.buf.hover)

    vim.api.nvim_buf_create_user_command(bufnr, "Format", function()
      vim.lsp.buf.format()
    end, { force = true })

    if client and client.name:match("ltex") then
      require("ltex_extra").setup({
        load_langs = { "en-US" },
        path = ".ltex",
      })
    end
  end,
})

vim.lsp.enable({
  "lua_ls",
  "ltex_plus",
  "harper_ls",
  "hls",
  "millet",
  "nil_ls",
  "pyright",
  "ts_ls",
  "vale_ls",
})
