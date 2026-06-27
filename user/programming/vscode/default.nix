{ pkgs, ... }:

let
  marketplaceExtensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      publisher = "NishantUnavane";
      name = "Ollama-Ai-agent";
      version = "1.3.5";
      sha256 = "051hj0s0x6mnzc38x12f5lxdrgaiswnr0zy8i58kw91gr6iwg71s";
    }
    # {
    #   publisher = "sst-dev";
    #   name = "opencode";
    #   version = "0.0.13";
    #   sha256 = "sha256-6adXUaoh/OP5yYItH3GAQ7GpupfmTGaxkKP6hYUMYNQ=";
    # }
  ];
in {
  programs.vscode = {
    enable = true;
    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          azdavis.millet

          jnoortheen.nix-ide

          bungcip.better-toml

          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          github.copilot
          github.copilot-chat

          haskell.haskell
          justusadam.language-haskell

          julialang.language-julia

          ms-python.python
          ms-python.pylint
          ms-python.black-formatter
          ms-python.vscode-pylance

          ms-toolsai.jupyter

          ms-vsliveshare.vsliveshare

          dbaeumer.vscode-eslint
          prettier.prettier-vscode

          rust-lang.rust-analyzer

          svelte.svelte-vscode

          tomoki1207.pdf
          
          vadimcn.vscode-lldb

          vitest.explorer

          vscodevim.vim
        ] ++ marketplaceExtensions;

        userSettings = {
          "vim.useSystemClipboard" = true;
          "vim.hlsearch" = true;

          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin";

          "notebook.defaultFormatter" = "ms-python.black-formatter";
          "millet.server.diagnostics.moreInfoHint.enable" = false;

          "editor.minimap.enabled" = false;
          "editor.semanticHighlighting.enabled" = true;

          "files.associations" = {
            "*.cabal" = "cabal";
            "*.hs" = "haskell";
            "*.lhs" = "literate haskell";
            "*.nix" = "nix";
            "*.svelte" = "svelte";
          };

          "svelte.enable-ts-plugin" = true;
          "svelte.ask-to-enable-ts-plugin" = false;
          "svelte.plugin.css.enable" = true;
          "svelte.plugin.html.enable" = true;
          "svelte.plugin.typescript.enable" = true;
          "svelte.plugin.typescript.semanticTokens.enable" = true;

          "eslint.validate" = [
            "javascript"
            "javascriptreact"
            "typescript"
            "typescriptreact"
            "svelte"
          ];
          "eslint.workingDirectories" = [
            {
              "mode" = "auto";
            }
          ];

          "ollamaAgent" = {
            "host" = "127.0.0.1";
            "port" = 11434;
            "provider" = "ollama";
          };
          
          "chat.tools.urls.autoApprove" = {
            "https://code.visualstudio.com" = true;
            "https://github.com/microsoft/vscode/wiki/*" = true;
            "https://mynixos.com" = true;
          };
        };
      };
    };
  };
}
