{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          azdavis.millet

          bbenoist.nix

          bungcip.better-toml

          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          github.copilot
          github.copilot-chat

          julialang.language-julia

          ms-python.python
          ms-python.pylint
          ms-python.black-formatter
          ms-python.vscode-pylance

          ms-toolsai.jupyter

          ms-vsliveshare.vsliveshare

          rust-lang.rust-analyzer

          tomoki1207.pdf
          
          vadimcn.vscode-lldb

          vscodevim.vim
        ];

        userSettings = {
          "vim.useSystemClipboard" = true;
          "vim.hlsearch" = true;
          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin";
          "notebook.defaultFormatter" = "ms-python.black-formatter";
          "millet.server.diagnostics.moreInfoHint.enable" = false;
          "editor.minimap.enabled" = false;
        };
      };
    };
  };
}
