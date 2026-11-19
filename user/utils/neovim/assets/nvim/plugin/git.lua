require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = desc })
    end
    map("]h", function() gs.nav_hunk("next") end, "Next Git hunk")
    map("[h", function() gs.nav_hunk("prev") end, "Previous Git hunk")
    map("<leader>gp", gs.preview_hunk, "Preview Git hunk")
    map("<leader>gs", gs.stage_hunk, "Stage Git hunk")
    map("<leader>gr", gs.reset_hunk, "Reset Git hunk")
  end,
})
