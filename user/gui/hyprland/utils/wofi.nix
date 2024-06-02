{ config, pkgs, ... }:

{
  programs.wofi = {
    enable = true;
  };

  home.file.wofi-conf = {
    source = ./assets/wofi;
    target = ".config/wofi";
    recursive = true;
  };
}
