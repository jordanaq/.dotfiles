# Neovim

Neovim is configured declaratively by Home Manager (`user/utils/neovim/default.nix`).
Plugin versions come from `flake.lock`/Nixpkgs. Do **not** use `lazy.nvim`
for a second copy of the plugin inventory.

Heavily inspired by [Vimjoyer's Neovim guide](https://youtu.be/YZAnJ0rwREA?si=IJYKeHpk4viX1upY).

## What changed

- `blink.cmp` + native `vim.snippet` replace `nvim-cmp`, the cmp sources,
  LuaSnip, and its config file.
- `snacks.nvim` picker/explorer replace Telescope, telescope-fzf-native,
  and Neo-tree. Existing LSP symbol/reference mappings continue using Snacks.
- `mini.nvim` provides text objects, surround, comments, icons, tabline,
  and statusline; standalone Comment, Bufferline, Lualine, and devicons are
  no longer installed. Surround motions: `sa`, `sd`, `sr`; comments: `gc`.
- `lazydev.nvim` replaces `neodev.nvim`.
- Native LSP setup enables the servers listed in `lspServers` in `default.nix`.
  Each entry can declare a Nix package and server settings. Omit `package`
  when another module or your project shell provides the executable. Julia
  stays disabled until a working Julia environment is configured.
- Gitsigns, Trouble, Flash, and Conform provide Git hunk tools, a diagnostics
  panel, fast jumps, and explicit formatting.
- Native `vim.hl.on_yank()` replaces the yank-highlighting plugin.
- `lazy.nvim` was unused as a package manager; Home Manager already manages
  plugins.

## Mappings

| Keys | Action |
| --- | --- |
| `<leader>e` | Snacks explorer |
| `<leader>ff` | Find files |
| `<leader>fg` | Grep project |
| `<leader>fb` | Find buffers |
| `<leader>fh` | Find Neovim help |
| `<leader>s`, `<leader>S`, `gr` | Document symbols, workspace symbols, references (Snacks) |
| `<leader>xx`, `<leader>xb` | Workspace/buffer diagnostics (Trouble) |
| `<leader>j`, `<leader>J` | Flash jump, syntax-aware Flash |
| `]h`, `[h`, `<leader>gp`, `<leader>gs`, `<leader>gr` | Git hunk operations |
| `<leader>cf`, `:Format` | Format buffer using Conform, with LSP fallback |
| `sa`, `sd`, `sr` | Mini surround add/delete/replace |
| `gc` | Mini comment |

Existing `CodeCompanion` keymaps are unchanged. Blink uses Enter to accept
completion and Tab/Shift-Tab for snippet navigation.

Formatting is **manual** until you opt into format-on-save. CLI formatters
`nixfmt`, `stylua`, `shfmt`, `ruff`, and `fourmolu` are available through
Home Manager; `clang-format` comes from `clang-tools`. Rust formatting uses
`rustfmt` if found in PATH, otherwise the LSP fallback.

## Deferred decisions

- `obsidian.nvim` stays installed but requires your vault/workspace path
  to enable it. Do not guess an Obsidian vault location here.
- The current Tree-sitter all-grammars set is preserved for less common
  languages (notably SML). Prune parsers only after checking your workflow.
- Consider `nvim-treesitter-textobjects` for function-definition text objects
  after testing `mini.ai`. Don't enable overlapping mappings blindly.

## Test

From the repository root on a clean review branch:

```sh
nix build '.?submodules=1#homeConfigurations.tsiru.activationPackage' --no-link
home-manager switch --flake '.?submodules=1#tsiru'
nvim +checkhealth
```

Launch Neovim and test completion, LSP references, project search,
`:Format`, and CodeCompanion. This patch intentionally does not modify
`flake.lock` or the Nous Portal API adapter.
