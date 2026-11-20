{ lib, pkgs, ... }:

let
  readLua = builtins.readFile;

  latexFiletypes = [ "bib" "context" "plaintex" "tex" ];
  englishLtex = {
    checkFrequency = "save";
    language = "en-US";
  };

  # A server must be listed here for Neovim to enable it.
  lspServers = with pkgs; [
    { name = "bashls"; package = bash-language-server; }
    { name = "clangd"; package = clang-tools; }
    { name = "cssls"; package = vscode-langservers-extracted; }
    { name = "elixirls"; package = elixir-ls; }
    {
      name = "eslint";
      package = vscode-langservers-extracted;
      settings.workingDirectory.mode = "auto";
    }
    { name = "html"; package = vscode-langservers-extracted; }
    { name = "jsonls"; package = vscode-langservers-extracted; }
    { name = "lua_ls"; package = lua-language-server; }
    {
      # ltex_extra recognizes both ltex and ltex_plus for dictionary commands.
      name = "ltex";
      base = "ltex_plus";
      filetypes = latexFiletypes;
      settings.ltex = englishLtex;
    }
    {
      name = "ltex_plus";
      package = ltex-ls-plus;
      filetypes = [
        "asciidoc"
        "gitcommit"
        "html"
        "markdown"
        "org"
        "pandoc"
        "quarto"
        "mail"
        "mdx"
        "rmd"
        "rnoweb"
        "rst"
        "text"
        "typst"
        "xhtml"
      ];
      settings.ltex = englishLtex // {
        languageToolHttpServerUri = "https://tsiru-cloud.tail892cfb.ts.net:8091";
      };
    }
    {
      name = "harper_ls";
      # The harper-web module already provides harper-ls on PATH.
      # LTeX+ handles prose formats. Keep Harper for source code and TOML.
      filetypes = [
        "c"
        "cpp"
        "cs"
        "go"
        "java"
        "javascript"
        "lua"
        "nix"
        "python"
        "ruby"
        "rust"
        "swift"
        "toml"
        "typescript"
        "typescriptreact"
        "haskell"
        "cmake"
        "php"
        "dart"
        "clojure"
        "sh"
      ];
      settings."harper-ls".userDictPath = "~/dict.txt";
    }
    { name = "hls"; package = haskell-language-server; }
    # SymbolServer 8.0.1 fails to precompile on Julia 1.13.3.
    # Re-enable with julia_112 or once the default Julia build works.
    # { name = "julials"; package = julia_112.withPackages [ "LanguageServer" "StaticLint" "SymbolServer" ]; }
    { name = "marksman"; package = marksman; }
    {
      name = "millet";
      package = millet;
      cmd = [ "millet-ls" ];
    }
    { name = "nil_ls"; package = nil; }
    { name = "pyright"; package = pyright; }
    { name = "rust_analyzer"; package = rust-analyzer; }
    { name = "svelte"; package = svelte-language-server; }
    { name = "taplo"; package = taplo; }
    { name = "ts_ls"; package = typescript-language-server; }
    {
      name = "vale_ls";
      package = vale-ls;
      # Vale needs project rules. Its upstream root marker is .vale.ini.
      workspace_required = true;
      project_config = ".vale.ini";
    }
    { name = "yamlls"; package = yaml-language-server; }
  ];

  settings = {
    editor = {
      globals = {
        mapleader = " ";
        maplocalleader = " ";
        vimtex_view_method = "zathura";
      };
      options = {
        clipboard = "unnamedplus";
        number = true;
        signcolumn = "yes";
        splitright = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        updatetime = 300;
        termguicolors = true;
        mouse = "a";
      };
      filetypes.extension = {
        cabal = "cabal";
        fun = "sml";
        hs = "haskell";
        lhs = "lhaskell";
        nix = "nix";
        sig = "sml";
        sml = "sml";
        svelte = "svelte";
        toml = "toml";
      };
      cIndent = {
        filetypes = [ "c" "cpp" ];
        options = {
          tabstop = 4;
          shiftwidth = 4;
          expandtab = true;
        };
      };
      yankHighlight.timeout = 300;
    };

    colorscheme = "catppuccin-macchiato";
    lspServers = map (server: removeAttrs server [ "package" ]) lspServers;
    ltexExtra = {
      init_check = false;
      load_langs = [ "en-US" ];
      path = ".ltex";
    };

    blink = {
      keymap = {
        preset = "enter";
        "<C-n>" = [ "select_next" "fallback" ];
        "<C-p>" = [ "select_prev" "fallback" ];
        "<Tab>" = [ "snippet_forward" "fallback" ];
        "<S-Tab>" = [ "snippet_backward" "fallback" ];
      };
      completion.documentation.auto_show = true;
      snippets.preset = "default";
      sources = {
        default = [ "lazydev" "lsp" "path" "snippets" "buffer" ];
        providers.lazydev = {
          name = "LazyDev";
          module = "lazydev.integrations.blink";
          score_offset = 100;
        };
      };
    };

    mini.modules = [ "icons" "ai" "surround" "comment" "tabline" "statusline" ];
    mini.textobjects = {
      F = { a = "@function.outer"; i = "@function.inner"; };
      C = { a = "@class.outer"; i = "@class.inner"; };
      P = { a = "@parameter.outer"; i = "@parameter.inner"; };
    };

    snacks = {
      picker.enabled = true;
      explorer.enabled = true;
    };

    conform.formatters_by_ft = {
      nix = [ "nixfmt" ];
      lua = [ "stylua" ];
      sh = [ "shfmt" ];
      bash = [ "shfmt" ];
      python = [ "ruff_format" ];
      haskell = [ "fourmolu" ];
      c = [ "clang_format" ];
      cpp = [ "clang_format" ];
      rust = [ "rustfmt" ];
      elixir = [ "mix" ];
      javascript = [ "prettier" ];
      javascriptreact = [ "prettier" ];
      typescript = [ "prettier" ];
      typescriptreact = [ "prettier" ];
      json = [ "prettier" ];
      jsonc = [ "prettier" ];
      yaml = [ "prettier" ];
      markdown = [ "prettier" ];
      "markdown.mdx" = [ "prettier" ];
      # Svelte's language server supplies the formatter with Svelte parser support.
    };

    codecompanion = {
      chatWindow = {
        layout = "vertical";
        position = "right";
      };
      # The adapter reads this environment variable at runtime.
      adapter = {
        name = "openai";
        model = "deepseek/deepseek-v4-flash";
      };
      env = {
        url = "https://inference-api.nousresearch.com/v1";
        api_key_name = "NOUS_API_KEY";
      };
    };

    noice = {
      lsp.override = {
        "vim.lsp.util.convert_input_to_markdown_lines" = true;
        "vim.lsp.util.stylize_markdown" = true;
      };
      presets = {
        bottom_search = true;
        command_palette = true;
        long_message_to_split = true;
        inc_rename = false;
        lsp_doc_border = false;
      };
    };
  };
in
{
  xdg.configFile."nvim/dotfiles-settings.json".text = builtins.toJSON settings;
  xdg.configFile."nvim/lua/dotfiles/settings.lua".source = ./assets/nvim/lua/dotfiles/settings.lua;

  programs.neovim = {
    enable = true;

    withRuby = true;
    withPython3 = true;

    package = pkgs.neovim-unwrapped;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = (with pkgs; [
      # AI assistant tooling
      curl
      file
      ripgrep

      # CLI formatters used by conform.nvim (opt-in with :Format).
      nixfmt
      stylua
      shfmt
      ruff
      fourmolu
      prettier
    ]) ++ lib.unique (lib.catAttrs "package" lspServers);

    # Plugins are installed and pinned by Nixpkgs; no second plugin manager.
    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim

      # Modern LSP completion; native vim.snippet removes the LuaSnip dependency.
      {
        plugin = blink-cmp;
        type = "lua";
        config = readLua ./assets/nvim/plugin/blink.lua;
      }
      {
        plugin = lazydev-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/lazydev.lua;
      }
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = readLua ./assets/nvim/plugin/lsp.lua;
      }
      ltex_extra-nvim

      # Mini replaces Comment.nvim, Bufferline, Lualine and devicons, while
      # also adding surround and richer text objects.
      {
        plugin = mini-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/mini.lua;
      }
      # Snacks replaces Telescope/FZF and Neo-tree with one picker/explorer.
      {
        plugin = snacks-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/snacks.lua;
      }

      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/git.lua;
      }
      {
        plugin = trouble-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/trouble.lua;
      }
      {
        plugin = flash-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/flash.lua;
      }
      {
        plugin = conform-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/format.lua;
      }

      {
        plugin = codecompanion-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/codecompanion.lua;
      }

      {
        plugin = noice-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/noice.lua;
      }

      # Obsidian requires a user-specific vault/workspace setup; keep installed
      # for now rather than inventing a vault location in the shared config.
      obsidian-nvim
      {
        plugin = persistence-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/persistence.lua;
      }

      # Preserve all grammars for the existing broad and niche language set.
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        config = readLua ./assets/nvim/plugin/treesitter.lua;
      }
      # Query files for mini.ai. Keep the mappings and selection logic in Mini.
      nvim-treesitter-textobjects
      vim-nix
      vimtex
      {
        plugin = which-key-nvim;
        type = "lua";
        config = readLua ./assets/nvim/plugin/which-key.lua;
      }
    ];

    initLua = readLua ./assets/nvim/init.lua;
  };

  # Self-clearing reminder: delete this entry when the Julia LSP comes back.
  warnings = [
    "${__curPos.file}:${toString __curPos.line}: TODO: the Julia language server is removed from neovim — nixpkgs' SymbolServer 8.0.1 cannot precompile on Julia 1.13 (`KeyError: key :_apply not found`). Re-enable in lspServers with (julia_112.withPackages [ \"LanguageServer\" \"StaticLint\" \"SymbolServer\" ]) — verified building — or plain julia once SymbolServer supports 1.13, then delete this warning."
  ];
}
