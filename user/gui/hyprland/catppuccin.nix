{ config, pkgs, ... }:

{
  home.file.catppuccin = {
    enable = true;
    source = ./catppuccin;
    target = ".config/hypr/catppuccin";
    recursive = true;
  };
}
