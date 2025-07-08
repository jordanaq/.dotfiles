{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          ms-python.python
          # ms-python.pylint
          # ms-python.black-formatter
          # ms-python.vscode-pylance

          ms-toolsai.jupyter

          ms-vsliveshare.vsliveshare
        ];
      };
    };
  };
}
