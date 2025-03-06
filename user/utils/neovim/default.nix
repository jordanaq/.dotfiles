{ config, pkgs, ... }:

{
  programs.neovim = let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in {
    enable = true;

    #package = pkgs.neovim;
    #defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

	extraPackages = with pkgs; [
	  # Language servers
	  lua-language-server
	  nil
	];

    plugins = with pkgs.vimPlugins; [
      lazy-nvim
      vim-nix
      neodev-nvim

      neo-tree-nvim
      oil-nvim
      {
        plugin = catppuccin-nvim;
        config = "colorscheme catppuccin-macchiato";
      }
      lazy-lsp-nvim
      lsp-zero-nvim

      {
        plugin = nvim-lspconfig;
        config = toLuaFile ./assets/nvim/plugin/lsp.lua;
      }

      {
        plugin = comment-nvim;
	      config = toLua "require(\"Comment\").setup()";
      }

      nvim-cmp 
      {
        plugin = nvim-cmp;
        config = toLuaFile ./assets/nvim/plugin/cmp.lua;
      }
      cmp_luasnip
      cmp-nvim-lsp

      {
        plugin = telescope-nvim;
        config = toLuaFile ./assets/nvim/plugin/telescope.lua;
      }
      telescope-fzf-native-nvim

      luasnip
      friendly-snippets

      lualine-nvim
      nvim-web-devicons

      {
        plugin = (nvim-treesitter.withPlugins (p: [
          p.tree-sitter-nix
          p.tree-sitter-vim
          p.tree-sitter-bash
          p.tree-sitter-lua
          p.tree-sitter-python
          p.tree-sitter-json
        ]));
        config = toLuaFile ./assets/nvim/plugin/treesitter.lua;
      }
    ];

    extraLuaConfig = ''

      vim.g.mapleader = ' '
      vim.g.maplocalleader = ' '
      
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
