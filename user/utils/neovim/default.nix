{ config, pkgs, ... }:

{
  programs.neovim = let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in {
    enable = true;

    package = pkgs.neovim-unwrapped;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      # Language servers
      harper
      haskell-language-server
      ltex-ls-plus
      lua-language-server
      millet
      nil
      pyright
      typescript-language-server
      vale-ls
    ];

    plugins = with pkgs.vimPlugins; [
      {
        plugin = bufferline-nvim;
        config = toLua "require('bufferline').setup{}";
      }

      {
        plugin = catppuccin-nvim;
        config = "colorscheme catppuccin-macchiato";
      }

      cmp_luasnip
      cmp-nvim-lsp

      {
        plugin = comment-nvim;
	      config = toLua "require(\"Comment\").setup()";
      }



      lazy-nvim
      {
        plugin = lazy-lsp-nvim;
        config = toLua ''
          require("lazy-lsp").setup {
            prefer_local = true
          }
        '';
      }
      {
        plugin = lsp-zero-nvim;
        config = toLuaFile ./assets/nvim/plugin/lsp.lua;
      }

      ltex_extra-nvim

      luasnip
      lualine-nvim

      nvim-lspconfig

      neodev-nvim

      {
        plugin = neo-tree-nvim;
        config = toLua "vim.keymap.set('n', '<Leader>e', '<Cmd>Neotree toggle<CR>', { noremap = true, silent = true })";
      }

      {
        plugin = noice-nvim;
        config = toLua ''
          require("noice").setup({
            lsp = {
              override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
                ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
              },
            },
            presets = {
              bottom_search = true, -- use a classic bottom cmdline for search
              command_palette = true, -- position the cmdline and popupmenu together
              long_message_to_split = true, -- long messages will be sent to a split
              inc_rename = false, -- enables an input dialog for inc-rename.nvim
              lsp_doc_border = false, -- add a border to hover docs and signature help
            },
          })
        '';
      }

      nvim-cmp 
      {
        plugin = nvim-cmp;
        config = toLuaFile ./assets/nvim/plugin/cmp.lua;
      }

      nvim-web-devicons

      persistence-nvim

      telescope-fzf-native-nvim
      {
        plugin = telescope-nvim;
        config = toLuaFile ./assets/nvim/plugin/telescope.lua;
      }

      {
        plugin = nvim-treesitter.withAllGrammars;
          #(nvim-treesitter.withPlugins (p: [
          #  p.tree-sitter-nix
          #  p.tree-sitter-vim
          #  p.tree-sitter-bash
          #  p.tree-sitter-lua
          #  p.tree-sitter-python
          #  p.tree-sitter-json
          #]));
        config = toLuaFile ./assets/nvim/plugin/treesitter.lua;
      }

      {
        plugin = vim-highlightedyank;
        config = toLua "vim.g.highlightedyank_highlight_duration = 300";
      }

      vim-nix

      {
        plugin = vimtex;
        type = "lua";
        config = ''
          vim.g.vimtex_view_method = "zathura"
        '';
      }

      which-key-nvim
    ];

    extraLuaConfig = ''

      vim.g.mapleader = ' '
      vim.g.maplocalleader = ' '
      
      vim.keymap.set('n', '<Space>', '<Nop>', { noremap = true, silent = true })
      vim.keymap.set('v', '<Space>', '<Nop>', { noremap = true, silent = true })

      vim.o.clipboard = 'unnamedplus'
      
      vim.o.number = true
      -- vim.o.relativenumber = true
      
      vim.o.signcolumn = 'yes'
      
      vim.o.tabstop = 2
      vim.o.shiftwidth = 2
      vim.o.expandtab = true
      
      vim.o.updatetime = 300
      
      vim.o.termguicolors = true
      
      vim.o.mouse = 'a'
    '';
  };
}
