{ config, ... }:

{
  home.file.bat-themes = {
    source = ./assets/bat/themes;
    target = ".config/bat/themes";
    recursive = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin-macchiato";
    };
  };
}
