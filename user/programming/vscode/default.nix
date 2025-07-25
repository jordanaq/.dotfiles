{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix

          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          github.copilot
          github.copilot-chat

          ms-python.python
          ms-python.pylint
          ms-python.black-formatter
          ms-python.vscode-pylance

          ms-toolsai.jupyter

          ms-vsliveshare.vsliveshare

          tomoki1207.pdf
          
          vscodevim.vim
        ];

        userSettings = {
          "vim.useSystemClipboard" = true;
          "vim.hlsearch" = true;
          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin";
        };
      };
    };
  };
}
