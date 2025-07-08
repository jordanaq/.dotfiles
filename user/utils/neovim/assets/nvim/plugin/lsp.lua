--local on_attach = function(_, bufnr)
--
--  local bufmap = function(keys, func)
--    vim.keymap.set('n', keys, func, { buffer = bufnr })
--  end
--
--  bufmap('<leader>r', vim.lsp.buf.rename)
--  bufmap('<leader>a', vim.lsp.buf.code_action)
--
--  bufmap('gd', vim.lsp.buf.definition)
--  bufmap('gD', vim.lsp.buf.declaration)
--  bufmap('gI', vim.lsp.buf.implementation)
--  bufmap('<leader>D', vim.lsp.buf.type_definition)
--
--  bufmap('gr', require('telescope.builtin').lsp_references)
--  bufmap('<leader>s', require('telescope.builtin').lsp_document_symbols)
--  bufmap('<leader>S', require('telescope.builtin').lsp_dynamic_workspace_symbols)
--
--  bufmap('K', vim.lsp.buf.hover)
--
--  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
--    vim.lsp.buf.format()
--  end, {})
--end
--
--local capabilities = vim.lsp.protocol.make_client_capabilities()
--capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local lsp_zero = require("lsp-zero")
lsp_zero.preset('recommended')

lsp_zero.extend_lspconfig("harper_ls", {
  settings = {
    harper_ls = {
      userDictPath = "~/dict.txt",
      filetypes = {
        "c",
        "cpp",
        "cs",
        "gitcommit",
        "go",
        "html",
        "java",
        "javascript",
        "lua",
        "markdown",
        "nix",
        "python",
        "ruby",
        "rust",
        "sml",
        "swift",
        "tex",
        "toml",
        "typescript",
        "typescriptreact",
        "haskell",
        "cmake",
        "typst",
        "php",
        "dart"
      }
    }
  },
})

lsp_zero.extend_lspconfig("ltex-plus", {
  settings = {
    ltex = {
      checkFrequency = "save",
      language = "en-US",
    },
  },
})

lsp_zero.setup_servers({
  'lua_ls',
  'ltex-plus',
  'harper_ls',
  'hls',
  'millet',
  'pyright',
  'tsserver',
  'vale_ls',
})

lsp_zero.on_attach(function(client, bufnr)
  lsp_zero.default_keymaps({ buffer = bufnr })

  if client.name:match("ltex") then
    require("ltex_extra").setup({
      load_langs = { "en-US" },
      path = ".ltex",
    })
  end
end)

lsp_zero.setup()

--require('neodev').setup()
--require('lspconfig').lua_ls.setup {
--  on_attach = on_attach,
--  capabilities = capabilities,
--    root_dir = function()
--      return vim.loop.cwd()
--  end,
--    cmd = { "lua-language-server" },
--  settings = {
--      Lua = {
--          workspace = { checkThirdParty = false },
--          telemetry = { enable = false },
--      },
--  }
--}
--
--require('lspconfig').nil.setup {
--    on_attach = on_attach,
--    capabilities = capabilities,
--    cmd = { "nil" },
--}
